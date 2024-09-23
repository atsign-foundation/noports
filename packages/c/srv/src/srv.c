#include "srv/srv.h"
#include "srv/params.h"
#include "srv/side.h"
#include <atchops/base64.h>
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define TAG "srv - run"

static void *run_socket_to_socket(void *args);

static int process_multiple_requests(char *original, char **requests[], size_t *num_out_requests);

static int parse_control_message(char *original, char **message_type, char **new_session_aes_key_string,
                                 char **new_session_aes_iv_string);

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
    res = create_encrypter_and_decrypter(params->session_aes_key_string, params->session_aes_iv_string, &encrypter,
                                         &decrypter);
    if (res != 0) {
      atlogger_log(TAG, ERROR, "run_srv_daemon_side_single: Error creating new encrypter and decrypter: %d\n", res);
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
    res = create_encrypter_and_decrypter(params->session_aes_key_string, params->session_aes_iv_string, &encrypter,
                                         &decrypter);
    if (res != 0) {
      atlogger_log(TAG, ERROR, "run_srv_daemon_side_multi: Error creating new encrypter and decrypter: %d\n", res);
    }
  }

  // Open a control socket of type B (non local host and port)
  // This socket will decrypt the messages comming from the other side
  // which provide the information to create new sockets
  side_t control_side;
  side_hints_t hints_control = {1, 0, params->host, params->port};
  if (params->rv_e2ee) {
    hints_control.transformer = &decrypter;
  }

  atlogger_log(TAG, INFO, "Initializing connection for control side\n");
  res = srv_side_init(&hints_control, &control_side);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to initialize connection for control side\n");
    return res;
  }

  // send the auth string to the other side
  if (params->rv_auth == 1) {
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

  size_t len;
  while ((res = mbedtls_net_recv(&control_side.socket, buffer, 4096)) > 0) {
    if (res < 0) {
      atlogger_log("srv - control (side b)", ERROR, "Error reading data: %d", len);
      goto exit;
    } else {
      len = res;
    }

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
    }

    char *messagetype = NULL, *new_session_aes_key_string = NULL, *new_session_aes_iv_string = NULL;

    atlogger_log(TAG, INFO, "requests buffer is: %s\n", buffer);

    // First, check if the buffer contains just one or more requests
    size_t nrequests = 0;
    res = process_multiple_requests((char *)buffer, &requests, &nrequests);
    if (res != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Failed to find any request from: %s\n", buffer);
      goto exit;
    }

    for (int i = 0; i < nrequests; i++) {
      // Now process each of those requests
      res = parse_control_message(requests[i], &messagetype, &new_session_aes_key_string, &new_session_aes_iv_string);
      if (res != 0) {
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Failed to find request type, aes key and/or iv from: %s\n",
                     requests[i]);
        goto exit;
      }
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "\tRECV: %s:%s:%s\n", messagetype, new_session_aes_key_string,
                   new_session_aes_iv_string);

      if (strcmp(messagetype, "connect") == 0) {
        chunked_transformer_t *new_socket_encrypter = malloc(sizeof(chunked_transformer_t));
        chunked_transformer_t *new_socket_decrypter = malloc(sizeof(chunked_transformer_t));
        if (new_socket_encrypter == NULL || new_socket_decrypter == NULL) {
          atlogger_log(TAG, ERROR, "Failed to allocate memory for new enc/dec\n");
          free(new_socket_encrypter);
          free(new_socket_decrypter);
          goto exit;
        }
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG,
                     "run_srv_daemon_side_multi\n Control socket received %s request - \n creating new socketToSocket "
                     "connection\n",
                     messagetype);
        // start socket_to_socket connection
        res = create_encrypter_and_decrypter(new_session_aes_key_string, new_session_aes_iv_string,
                                             new_socket_encrypter, new_socket_decrypter);
        atlogger_log(TAG, INFO, "Starting socket to socket srv\n");

        pthread_t sts_thread;
        socket_to_socket_params_t *sts_thread_params = malloc(sizeof(socket_to_socket_params_t));
        if (sts_thread_params == NULL) {
          atlogger_log(TAG, ERROR, "Failed to allocate memory for thread parameters\n");
          free(new_socket_encrypter);
          free(new_socket_decrypter);
          goto exit;
        }

        sts_thread_params->params = params;
        sts_thread_params->auth_string = params->rvd_auth_string;
        sts_thread_params->encrypter = new_socket_encrypter;
        sts_thread_params->decrypter = new_socket_decrypter;
        sts_thread_params->is_srv_ready = true;

        res = pthread_create(&sts_thread, NULL, run_socket_to_socket, (void *)sts_thread_params);
        if (res != 0) {
          atlogger_log(TAG, ERROR, "Failed to create thread: %d\n", res);
          free(new_socket_encrypter);
          free(new_socket_decrypter);
          free(sts_thread_params);
          goto exit;
        }

        pthread_detach(sts_thread);

      } else {
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Unknown request to control socket: %s\n", requests[i]);
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
  side_hints_t hints_a = {1, 0, params->local_host, params->local_port};
  side_hints_t hints_b = {0, 0, params->host, params->port};

  if (params->rv_e2ee) {
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
  pipe(fds);

  srv_link_sides(&sides[0], &sides[1], fds);

  atlogger_log(TAG, INFO, "Starting threads\n");
  // send the auth string to side b
  if (params->rv_auth == 1) {
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
  res = pthread_join(tid, (void *)&retval);

cancel:
  if (pthread_equal(threads[0], tid) > 0) {
    // If threads[0] exited normally then we will cancel threads[1]
    // In all other cases, cancel threads[0] (could be because threads[1] exited or errored)
    tidx = 1;
  } else {
    tidx = 0;
  }

  atlogger_log(TAG, DEBUG, "Cancelling remaining open thread: %d\n", tidx);
  if (pthread_cancel(threads[tidx]) != 0) {
    atlogger_log(TAG, WARN, "Failed to cancel thread: %d\n", tidx);
  } else {
    atlogger_log(TAG, DEBUG, "Canceled thread: %d\n", tidx);
  }

exit:
  close(fds[0]);
  close(fds[1]);

  if (params->rv_e2ee == 1) {
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
  return 0;
}

int create_encrypter_and_decrypter(const char *session_aes_key_string, const char *session_aes_iv_string,
                                   chunked_transformer_t *encrypter, chunked_transformer_t *decrypter) {
  int res = 0;
  atlogger_log(TAG, INFO, "Configuring encrypter/decrypter for srv\n");

  // Temporary buffer for decoding the key
  unsigned char aes_key[AES_256_KEY_BYTES];
  size_t aes_key_len;

  // Decode the key
  res = atchops_base64_decode((unsigned char *)session_aes_key_string, strlen(session_aes_key_string), aes_key,
                              AES_256_KEY_BYTES, &aes_key_len);

  if (res != 0 || aes_key_len != AES_256_KEY_BYTES) {
    atlogger_log(TAG, ERROR, "Error decoding session_aes_key_string\n");
    return res;
  }

  mbedtls_aes_init(&encrypter->aes_ctr.ctx); // FREE
  res = mbedtls_aes_setkey_enc(&encrypter->aes_ctr.ctx, aes_key, AES_256_KEY_BITS);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Error setting encryption key\n");
    mbedtls_aes_free(&encrypter->aes_ctr.ctx);
    return res;
  }

  mbedtls_aes_init(&decrypter->aes_ctr.ctx); // FREE
  res = mbedtls_aes_setkey_enc(&decrypter->aes_ctr.ctx, aes_key, AES_256_KEY_BITS);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Error setting decryption key\n");
    mbedtls_aes_free(&encrypter->aes_ctr.ctx);
    mbedtls_aes_free(&decrypter->aes_ctr.ctx);
    return res;
  }

  // Decode the iv
  size_t iv_len;
  res = atchops_base64_decode((unsigned char *)session_aes_iv_string, strlen(session_aes_iv_string),
                              encrypter->aes_ctr.nonce_counter, AES_BLOCK_LEN, &iv_len);
  if (res != 0 || iv_len != AES_BLOCK_LEN) {
    atlogger_log(TAG, ERROR, "Error decoding session_aes_iv_string\n");
    mbedtls_aes_free(&encrypter->aes_ctr.ctx);
    mbedtls_aes_free(&decrypter->aes_ctr.ctx);
    return res;
  }

  // Copy the iv to the decrypter
  memcpy(decrypter->aes_ctr.nonce_counter, encrypter->aes_ctr.nonce_counter, AES_BLOCK_LEN);

  // Set the stream blocks to 0
  memset(encrypter->aes_ctr.stream_block, 0, AES_BLOCK_LEN);
  memset(decrypter->aes_ctr.stream_block, 0, AES_BLOCK_LEN);

  // Set the iv offset to 0
  encrypter->aes_ctr.nc_off = 0;
  decrypter->aes_ctr.nc_off = 0;

  // Set the transform functions
  encrypter->transform = aes_ctr_crypt_stream;
  decrypter->transform = aes_ctr_crypt_stream;

  return res;
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
  int num_requests = 0;

  char *temp = NULL;
  char *saveptr = original;
  char **temp_requests = NULL;
  size_t temp_count = 0;

  while ((temp = strtok_r(saveptr, "\n", &saveptr))) {
    // realloc memory to save a new pointer
    temp_requests = realloc(temp_requests, (temp_count + 1) * sizeof(char *));
    if (!temp_requests) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "process_multiple_requests: Failed to allocate memory\n");
      goto exit;
    }

    temp_requests[temp_count] = temp;
    temp_count++;
  }

  *requests = temp_requests;
  *num_out_requests = temp_count;

  ret = 0;
  goto exit;
exit: { return ret; }
}

// connect:session_aes_key_string:session_aes_iv_string
static int parse_control_message(char *original, char **message_type, char **new_session_aes_key_string,
                                 char **new_session_aes_iv_string) {
  int ret = -1;

  char *temp = NULL;
  char *saveptr = original;

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
      *new_session_aes_key_string = temp;
    if (i == 2)
      *new_session_aes_iv_string = temp;
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

  return NULL;
}
