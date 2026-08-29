#include "srv/srv.h"
#include "srv/escr.h"
#include "srv/params.h"
#include "srv/side.h"
#include <atchops/base64.h>
#include <atlogger/atlogger.h>
#include <mbedtls/net_sockets.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define TAG "srv - run"

// How often the multi-mode control channel wakes up from recv to check the
// connection timeout
#define SRV_CONTROL_POLL_MS 1000

static void *run_socket_to_socket(void *args);

// Connection timeout state for multi mode: the srv exits once there have been
// no active socket-to-socket sessions for params->timeout seconds (matching
// the SocketConnector timeout semantics of the Dart srv). One process runs at
// most one run_srv_daemon_side_multi, so process-wide state is safe here.
static pthread_mutex_t session_mutex = PTHREAD_MUTEX_INITIALIZER;
static int active_sessions = 0;
static time_t idle_since = 0;

static void session_started(void) {
  pthread_mutex_lock(&session_mutex);
  active_sessions++;
  pthread_mutex_unlock(&session_mutex);
}

static void session_ended(void) {
  pthread_mutex_lock(&session_mutex);
  if (--active_sessions == 0) {
    idle_since = time(NULL);
  }
  pthread_mutex_unlock(&session_mutex);
}

static bool connection_timeout_expired(int timeout_seconds) {
  pthread_mutex_lock(&session_mutex);
  bool expired = active_sessions == 0 && difftime(time(NULL), idle_since) >= timeout_seconds;
  pthread_mutex_unlock(&session_mutex);
  return expired;
}

static int process_multiple_requests(char *original, char **requests[], size_t *num_out_requests);

static int parse_control_message(char *original, char **message_type, char **new_session_aes_key_c2d_string,
                                 char **new_session_aes_iv_c2d_string, char **new_session_aes_key_d2c_string,
                                 char **new_session_aes_iv_d2c_string);

int run_srv(srv_params_t *params) {
  int res = 0;
  if (params->bind_local_port == 0) {
    // daemon side
    if (params->multi == 0) {
      res = run_srv_daemon_side_single(params);
    } else {
      res = run_srv_daemon_side_multi(params);
    }
  } else {
    atlogger_log("srv - bind", ATLOGGER_LOGGING_LEVEL_ERROR, "--local-bind-port is disabled\n");
    exit(1);

    // atlogger_log(TAG, INFO, "Starting server to socket srv\n");
    // res = server_to_socket(params, params->rvd_auth_string, &encrypter, &decrypter);

    // client side
    if (params->multi == 0) {
      // res = run_srv_client_side_single(params);
      res = 1;
    } else {
      // todo: check aes key and iv strings != null
      res = 1;
      // res = run_srv_client_side_multi(params);
    }
  }
  return res;
}

int run_srv_daemon_side_single(srv_params_t *params) {

  chunked_transformer_t encrypter;
  chunked_transformer_t decrypter;

  int res;

  if (params->rv_e2ee == 1) {
    res = create_encrypter_and_decrypter(params->session_aes_key_c2d_string, params->session_aes_iv_c2d_string,
                                         params->session_aes_key_d2c_string, params->session_aes_iv_d2c_string,
                                         &encrypter, &decrypter);
    if (res != 0) {
      atlogger_log(TAG, ERROR, "run_srv_daemon_side_single: Error creating new encrypter and decrypter: %d\n", res);
      return res;
    }
  }

  atlogger_log(TAG, INFO, "Starting socket to socket srv\n");
  res = socket_to_socket(params, params->rvd_auth_string, &encrypter, &decrypter, false);

  if (params->rv_e2ee == 1) {
    mbedtls_aes_free(&encrypter.aes_ctr.ctx);
    mbedtls_aes_free(&decrypter.aes_ctr.ctx);
  }

  return res;
}

int run_srv_daemon_side_multi(srv_params_t *params) {

  chunked_transformer_t encrypter;
  chunked_transformer_t decrypter;

  char **requests = NULL;
  int res = 0;

  if (params->rv_e2ee == 1) {
    res = create_encrypter_and_decrypter(params->session_aes_key_c2d_string, params->session_aes_iv_c2d_string,
                                         params->session_aes_key_d2c_string, params->session_aes_iv_d2c_string,
                                         &encrypter, &decrypter);
    if (res != 0) {
      atlogger_log(TAG, ERROR, "run_srv_daemon_side_multi: Error creating new encrypter and decrypter: %d\n", res);
      return res;
    }
  }

  // Open a control channel of type B (non local host and port)
  // This socket will decrypt the messages comming from the other side
  // which provide the information to create new sockets
  side_t control_side;
  side_hints_t hints_control = {1, 0, params->host, params->port, NULL};
  if (params->rv_e2ee) {
    hints_control.transformer = &decrypter;
  }

  atlogger_log(TAG, INFO, "Initializing connection for control side\n");
  res = srv_side_init(&hints_control, &control_side);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to initialize connection for control side\n");
    return res;
  }

  // Authenticate the control channel to the relay
  if (params->escr_auth) {
    atlogger_log(TAG, INFO, "Authenticating control channel to relay (escr)\n");
    res = srv_escr_authenticate(&control_side.socket, params);
    if (res != 0) {
      atlogger_log(TAG, ERROR, "Failed to authenticate control channel to relay\n");
      mbedtls_net_close(&control_side.socket);
      return res;
    }
  } else if (params->rv_auth == 1) {
    atlogger_log(TAG, DEBUG, "Sending auth string: %s\n", (unsigned char *)params->rvd_auth_string);
    int len = strlen(params->rvd_auth_string);

    int slen = mbedtls_net_send(&control_side.socket, (unsigned char *)params->rvd_auth_string, len);
    slen += mbedtls_net_send(&control_side.socket, (unsigned char *)"\n", 1);
    if (slen != len + 1) {
      atlogger_log(TAG, ERROR, "Failed to send auth string\n");
      return -1;
    }
  }

  atlogger_log(TAG, INFO, "Starting recv loop\n");

  // signal to sshnpd that we are done
  fprintf(stderr, "%s\n", SRV_COMPLETION_STRING);
  fflush(stderr);

  unsigned char *buffer = malloc(4096 * sizeof(unsigned char));
  if (buffer == NULL) {
    return -1;
  }
  memset(buffer, 0, 4096 * sizeof(unsigned char));

  int timeout_seconds = params->timeout > 0 ? params->timeout : SRV_DEFAULT_TIMEOUT_SECONDS;
  pthread_mutex_lock(&session_mutex);
  idle_since = time(NULL);
  pthread_mutex_unlock(&session_mutex);

  size_t len;
  for (;;) {
    if (connection_timeout_expired(timeout_seconds)) {
      atlogger_log(TAG, INFO, "No connections for %d seconds - closing srv\n", timeout_seconds);
      res = 0;
      goto exit;
    }

    // Leave room for a NUL terminator: the relay bytes are attacker-controlled
    // and buffer is consumed with strtok_r/"%s", which read until a NUL.
    res = mbedtls_net_recv_timeout(&control_side.socket, buffer, 4095, SRV_CONTROL_POLL_MS);
    if (res == MBEDTLS_ERR_SSL_TIMEOUT) {
      continue;
    }
    if (res <= 0) {
      if (res < 0) {
        atlogger_log("srv - control (side b)", ERROR, "Error reading data from control socket: %d\n", res);
      }
      goto exit;
    }
    len = res;
    buffer[len] = '\0';

    if (control_side.transformer != NULL) {
      unsigned char *output = malloc(4096 * sizeof(unsigned char));
      if (output == NULL) {
        goto exit;
      }
      memset(output, 0, 4096 * sizeof(unsigned char));
      res = (int)control_side.transformer->transform(control_side.transformer, len, buffer, output);
      if (res != 0) {
        free(output);
        goto exit;
      }
      free(buffer);
      buffer = output;
      buffer[len] = '\0';
    }

    char *messagetype = NULL, *new_session_aes_key_c2d_string = NULL, *new_session_aes_iv_c2d_string = NULL,
         *new_session_aes_key_d2c_string = NULL, *new_session_aes_iv_d2c_string = NULL;

    atlogger_log(TAG, INFO, "requests buffer is: %s\n", buffer);

    // First, check if the buffer contains just one or more requests
    size_t nrequests = 0;
    res = process_multiple_requests((char *)buffer, &requests, &nrequests);
    if (res != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Failed to find any request from: %s\n", buffer);
      goto exit;
    }

    for (size_t i = 0; i < nrequests; i++) {
      // Now process each of those requests
      res = parse_control_message(requests[i], &messagetype, &new_session_aes_key_c2d_string, &new_session_aes_iv_c2d_string,
                                  &new_session_aes_key_d2c_string, &new_session_aes_iv_d2c_string);
      if (res != 0) {
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Failed to find request type, aes key and/or iv from: %s\n",
                     requests[i]);
        goto exit;
      }
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "\tRECV: %s:%s:%s (%s)\n", messagetype,
                   new_session_aes_key_c2d_string, new_session_aes_iv_c2d_string,
                   new_session_aes_key_d2c_string != NULL ? "twinned keys" : "single key");

      if (strcmp(messagetype, "connect") == 0) {
        chunked_transformer_t *new_socket_encrypter = NULL;
        chunked_transformer_t *new_socket_decrypter = NULL;
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG,
                     "run_srv_daemon_side_multi\n control channel received %s request - \n creating new socketToSocket "
                     "connection\n",
                     messagetype);

        bool no_encrypt =
            strcmp(new_session_aes_key_c2d_string, "no") == 0 && strcmp(new_session_aes_iv_c2d_string, "encrypt") == 0;
        if (no_encrypt) {
          atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                       "Socket connector requested no encryption!\n\tOnly disable encryption if you know what you "
                       "are doing!\n");
        }

        if (!no_encrypt) {
          new_socket_encrypter = malloc(sizeof(chunked_transformer_t));
          new_socket_decrypter = malloc(sizeof(chunked_transformer_t));
          if (new_socket_encrypter == NULL || new_socket_decrypter == NULL) {
            atlogger_log(TAG, ERROR, "Failed to allocate memory for new enc/dec\n");
            free(new_socket_encrypter);
            free(new_socket_decrypter);
            goto exit;
          }

          res = create_encrypter_and_decrypter(new_session_aes_key_c2d_string, new_session_aes_iv_c2d_string,
                                               new_session_aes_key_d2c_string, new_session_aes_iv_d2c_string,
                                               new_socket_encrypter, new_socket_decrypter);
          if (res != 0) {
            // A bad connect message must not take down the whole srv - skip
            // this request and keep serving the control channel
            atlogger_log(TAG, ERROR, "Failed to create enc/dec for connect request: %d - skipping request\n", res);
            free(new_socket_encrypter);
            free(new_socket_decrypter);
            continue;
          }
        }
        atlogger_log(TAG, INFO, "Starting socket to socket srv\n");

        pthread_t sts_thread;
        socket_to_socket_params_t *sts_thread_params = malloc(sizeof(socket_to_socket_params_t));
        if (sts_thread_params == NULL) {
          atlogger_log(TAG, ERROR, "Failed to allocate memory for thread parameters\n");
          if (!no_encrypt) {
            free(new_socket_encrypter);
            free(new_socket_decrypter);
          }
          goto exit;
        }

        sts_thread_params->params = params;
        sts_thread_params->auth_string = params->rvd_auth_string;
        sts_thread_params->encrypter = new_socket_encrypter;
        sts_thread_params->decrypter = new_socket_decrypter;
        sts_thread_params->is_srv_ready = true;

        // Count the session before the thread exists so the timeout check
        // can't fire in the gap between accepting the request and the
        // session becoming active
        session_started();

        res = pthread_create(&sts_thread, NULL, run_socket_to_socket, (void *)sts_thread_params);
        if (res != 0) {
          atlogger_log(TAG, ERROR, "Failed to create thread: %d\n", res);
          session_ended();
          if (!no_encrypt) {
            free(new_socket_encrypter);
            free(new_socket_decrypter);
          }
          free(sts_thread_params);
          goto exit;
        }

        pthread_detach(sts_thread);

      } else {
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Unknown request to control channel: %s\n", requests[i]);
      }
    }
    // Clean buffer for next iteration and free previous requests
    memset(buffer, 0, 4096);
    free(requests);
    requests = NULL;
  }

exit:
  free(buffer);
  if (requests)
    free(requests);
  mbedtls_net_close(&control_side.socket);
  if (params->rv_e2ee == 1) {
    mbedtls_aes_free(&encrypter.aes_ctr.ctx);
    mbedtls_aes_free(&decrypter.aes_ctr.ctx);
  }
  return res;
}

int socket_to_socket(const srv_params_t *params, const char *auth_string, chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter, bool is_srv_ready) {
  side_t sides[2];
  side_hints_t hints_a = {1, 0, params->local_host, params->local_port, NULL};
  side_hints_t hints_b = {0, 0, params->host, params->port, NULL};

  // encrypter/decrypter may be NULL even when rv_e2ee is set: a multi-mode
  // client can request an unencrypted socket with 'connect:no:encrypt'
  bool transform = params->rv_e2ee && encrypter != NULL && decrypter != NULL;
  if (transform) {
    hints_a.transformer = encrypter;
    hints_b.transformer = decrypter;
  }
  atlogger_log(TAG, INFO, "Initializing connection for side a\n");
  int res = srv_side_init(&hints_a, &sides[0]);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to initialize connection for side a\n");
    return res;
  }

  atlogger_log(TAG, INFO, "Initializing connection for side b\n");
  res = srv_side_init(&hints_b, &sides[1]);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to initialize connection for side b\n");
    return res;
  }

  int fds[2], tidx;
  int exit_res = 0;
  pthread_t threads[2], tid;
  bool cancel_first = false;
  pipe(fds);

  srv_link_sides(&sides[0], &sides[1], fds);

  atlogger_log(TAG, INFO, "Starting threads\n");
  // Authenticate side b (the relay side) - every socket to the relay
  // authenticates individually
  if (params->escr_auth) {
    atlogger_log(TAG, INFO, "Authenticating session socket to relay (escr)\n");
    res = srv_escr_authenticate(&sides[1].socket, params);
    if (res != 0) {
      atlogger_log(TAG, ERROR, "Failed to authenticate session socket to relay\n");
      exit_res = res;
      goto exit;
    }
  } else if (params->rv_auth == 1) {
    atlogger_log(TAG, INFO, "Sending auth string\n");
    int len = strlen(auth_string);

    int slen = mbedtls_net_send(&sides[1].socket, (unsigned char *)auth_string, len);
    slen += mbedtls_net_send(&sides[1].socket, (unsigned char *)"\n", 1);
    if (slen != len + 1) {
      atlogger_log(TAG, ERROR, "Failed to send auth string\n");
      return -1;
    }
  }

  res = pthread_create(&threads[0], NULL, srv_side_handle, &sides[0]);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to create thread: 0\n");
    exit_res = res;
    goto exit;
  }

  res = pthread_create(&threads[1], NULL, srv_side_handle, &sides[1]);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to create thread: 1\n");
    cancel_first = true;
    exit_res = res;
    goto cancel;
  }

  if (!is_srv_ready) {
    // signal to sshnpd that we are done
    fprintf(stderr, "%s\n", SRV_COMPLETION_STRING);
    fflush(stderr);
  }

  // Wait for all threads to finish and join them back to the main thread
  int retval = 0;

  // Wait for any pthread to exit
  read(fds[0], &tid, sizeof(pthread_t));

  atlogger_log(TAG, DEBUG, "Joining exited thread\n");

  // When a thread exits, join it.
  res = pthread_join(tid, (void *)&retval);

cancel:
  // Then figure out which thread didn't close
  if (!cancel_first && pthread_equal(threads[0], tid) > 0) {
    // If threads[0] exited normally then we will cancel threads[1]
    // In all other cases, cancel threads[0] (could be because threads[1] exited or errored)
    tidx = 1;
  } else {
    tidx = 0;
  }

  // Then cancel the other thread
  atlogger_log(TAG, DEBUG, "Cancelling remaining open thread: %d\n", tidx);
  if (pthread_cancel(threads[tidx]) != 0) {
    atlogger_log(TAG, WARN, "Failed to cancel thread: %d\n", tidx);
  } else {
    atlogger_log(TAG, DEBUG, "Canceled thread: %d\n", tidx);
  }

  // Reap the canceled thread so it is safe to close its socket below
  pthread_join(threads[tidx], NULL);

exit:
  close(fds[0]);
  close(fds[1]);

  // The thread which exited normally closed its own socket, but a canceled
  // thread never gets the chance - without this, every torn-down connection
  // leaks a file descriptor for the lifetime of a multi-mode srv process.
  // Safe to call on both sides: mbedtls_net_free is a no-op once fd == -1.
  srv_side_free(&sides[0]);
  srv_side_free(&sides[1]);

  if (transform) {
    mbedtls_aes_free(&encrypter->aes_ctr.ctx);
    mbedtls_aes_free(&decrypter->aes_ctr.ctx);
  }

  if (exit_res != 0) {
    return exit_res;
  }

  return 0;
}

int server_to_socket(const srv_params_t *params, const char *auth_string, chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter) {
  (void)params;
  (void)auth_string;
  (void)encrypter;
  (void)decrypter;
  return 1;
}

int create_transformer(const char *aes_key_base64, const char *aes_iv_base64, chunked_transformer_t *transformer) {
  int res = 0;

  // Temporary buffer for decoding the key
  unsigned char aes_key[AES_256_KEY_BYTES];
  size_t aes_key_len;

  // Decode the key
  res = atchops_base64_decode(aes_key_base64, strlen(aes_key_base64), aes_key, AES_256_KEY_BYTES, &aes_key_len);
  if (res != 0 || aes_key_len != AES_256_KEY_BYTES) {
    atlogger_log(TAG, ERROR, "Error decoding session aes key\n");
    return res != 0 ? res : 1;
  }

  mbedtls_aes_init(&transformer->aes_ctr.ctx); // FREE
  // NB: AES-CTR uses the encryption key schedule for both directions
  res = mbedtls_aes_setkey_enc(&transformer->aes_ctr.ctx, aes_key, AES_256_KEY_BITS);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Error setting session aes key\n");
    mbedtls_aes_free(&transformer->aes_ctr.ctx);
    return res;
  }

  // Decode the iv
  size_t iv_len;
  res = atchops_base64_decode(aes_iv_base64, strlen(aes_iv_base64), transformer->aes_ctr.nonce_counter, AES_BLOCK_LEN,
                              &iv_len);
  if (res != 0 || iv_len != AES_BLOCK_LEN) {
    atlogger_log(TAG, ERROR, "Error decoding session aes iv\n");
    mbedtls_aes_free(&transformer->aes_ctr.ctx);
    return res != 0 ? res : 1;
  }

  memset(transformer->aes_ctr.stream_block, 0, AES_BLOCK_LEN);
  transformer->aes_ctr.nc_off = 0;
  transformer->transform = aes_ctr_crypt_stream;

  return 0;
}

int create_encrypter_and_decrypter(const char *aes_key_c2d_base64, const char *aes_iv_c2d_base64,
                                   const char *aes_key_d2c_base64, const char *aes_iv_d2c_base64,
                                   chunked_transformer_t *encrypter, chunked_transformer_t *decrypter) {
  int res = 0;
  bool twin_keys = aes_key_d2c_base64 != NULL && aes_iv_d2c_base64 != NULL;
  atlogger_log(TAG, INFO, "Configuring encrypter/decrypter for srv (%s)\n",
               twin_keys ? "twinned keys" : "single key");

  // The decrypter always uses the C2D key - it decrypts what the client encrypted
  res = create_transformer(aes_key_c2d_base64, aes_iv_c2d_base64, decrypter);
  if (res != 0) {
    return res;
  }

  // The encrypter uses the D2C key when twinned, otherwise the same C2D key
  if (twin_keys) {
    res = create_transformer(aes_key_d2c_base64, aes_iv_d2c_base64, encrypter);
  } else {
    res = create_transformer(aes_key_c2d_base64, aes_iv_c2d_base64, encrypter);
  }
  if (res != 0) {
    mbedtls_aes_free(&decrypter->aes_ctr.ctx);
    return res;
  }

  return 0;
}

int aes_ctr_crypt_stream(const chunked_transformer_t *self, size_t len, const unsigned char *input,
                         unsigned char *output) {
  // Access the state from the self pointer
  aes_ctr_transformer_state_t *state = (aes_ctr_transformer_state_t *)&self->aes_ctr;

  // **crypt the buffer to the chunk
  int res =
      mbedtls_aes_crypt_ctr(&state->ctx, len, &state->nc_off, state->nonce_counter, state->stream_block, input, output);

  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to crypt chunk\n");
    return res;
  }

  return 0;
}

static int process_multiple_requests(char *original, char **requests[], size_t *num_out_requests) {
  int ret = -1;

  char *temp = NULL;
  char *saveptr = original;
  char **temp_requests = NULL;
  size_t temp_count = 0;

  while ((temp = strtok_r(saveptr, "\n", &saveptr))) {
    // realloc memory to save a new pointer
    char **grown = realloc(temp_requests, (temp_count + 1) * sizeof(char *));
    if (!grown) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "process_multiple_requests: Failed to allocate memory\n");
      free(temp_requests);
      goto exit;
    }
    temp_requests = grown;

    temp_requests[temp_count] = temp;
    temp_count++;
  }

  *requests = temp_requests;
  *num_out_requests = temp_count;

  ret = 0;
  goto exit;
exit: { return ret; }
}

// Legacy single key: connect:session_aes_key_c2d_string:session_aes_iv_c2d_string
// Twinned keys:      connect:aes_key_c2d:aes_iv_c2d:aes_key_d2c:aes_iv_d2c
// The d2c output strings are set to NULL when the message carries a single key.
static int parse_control_message(char *original, char **message_type, char **new_session_aes_key_c2d_string,
                                 char **new_session_aes_iv_c2d_string, char **new_session_aes_key_d2c_string,
                                 char **new_session_aes_iv_d2c_string) {
  int ret = -1;

  char *temp = NULL;
  char *saveptr = original;

  *new_session_aes_key_d2c_string = NULL;
  *new_session_aes_iv_d2c_string = NULL;

  // if message has any leading or trailing white space or new line characters, remove it
  while ((saveptr)[0] == ' ' || (saveptr)[0] == '\n') {
    saveptr = saveptr + 1;
  }
  size_t trail;
  do {
    trail = strlen(saveptr) - 1;
    if ((saveptr)[trail] == ' ' || (saveptr)[trail] == '\n') {
      (saveptr)[trail] = '\0';
    }
  } while ((saveptr)[trail] == ' ' || (saveptr)[trail] == '\n');

  for (int i = 0; i < 3; i++) {
    temp = strtok_r(saveptr, ":", &saveptr);
    if (temp == NULL) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to parse message type\n");
      goto exit;
    }
    if (i == 0)
      *message_type = temp;
    if (i == 1)
      *new_session_aes_key_c2d_string = temp;
    if (i == 2)
      *new_session_aes_iv_c2d_string = temp;
  }

  // Optional twinned d2c key and iv - must be present together
  temp = strtok_r(saveptr, ":", &saveptr);
  if (temp != NULL) {
    *new_session_aes_key_d2c_string = temp;
    temp = strtok_r(saveptr, ":", &saveptr);
    if (temp == NULL) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received a d2c aes key without a d2c iv\n");
      goto exit;
    }
    *new_session_aes_iv_d2c_string = temp;
  }

  ret = 0;
  goto exit;
exit: { return ret; }
}

static void *run_socket_to_socket(void *args) {
  socket_to_socket_params_t *sts_thread_params = (socket_to_socket_params_t *)args;
  socket_to_socket(sts_thread_params->params, sts_thread_params->auth_string, sts_thread_params->encrypter,
                   sts_thread_params->decrypter, sts_thread_params->is_srv_ready);

  free(sts_thread_params->encrypter);
  free(sts_thread_params->decrypter);
  free(sts_thread_params);

  session_ended();

  return NULL;
}
