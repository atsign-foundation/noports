#include "srv/socket_to_socket.h"
#include "srv/params.h"
#include "srv/srv.h"
#include "srv/stream.h"
#include <atlogger.h>
#include <srv/side.h>
#include <string.h>

#define TAG "srv - socket_to_socket"
int socket_to_socket(const srv_params_t *params, const char *auth_string,
                     chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter) {
  side_t sides[2];
  side_hints_t hints_a = {1, 0, NULL, params->local_port, encrypter};
  side_hints_t hints_b = {0, 0, params->host, params->port, decrypter};

  atclient_atlogger_log(TAG, INFO, "Initializing connection for side a\n");
  int res = srv_side_init(&hints_a, &sides[0]);
  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR,
                          "Failed to initialize connection for side a\n");
    return res;
  }

  atclient_atlogger_log(TAG, INFO, "Initializing connection for side b\n");
  res = srv_side_init(&hints_b, &sides[1]);
  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR,
                          "Failed to initialize connection for side b\n");
    return res;
  }

  int fds[2];
  pthread_t threads[2];
  pipe(fds);

  srv_link_sides(&sides[0], &sides[1], fds);

  atclient_atlogger_log(TAG, INFO, "Starting threads\n");
  // send the auth string to side b
  if (params->rv_auth == 1) {
    atclient_atlogger_log(TAG, INFO, "Sending auth string\n");
    int len = strlen(auth_string);

    int slen =
        mbedtls_net_send(sides[1].socket, (unsigned char *)auth_string, len);
    slen += mbedtls_net_send(sides[1].socket, (unsigned char *)"\n", 1);
    if (slen != len + 1) {
      atclient_atlogger_log(TAG, ERROR, "Failed to send auth string\n");
      return -1;
    }
  }

  for (int i = 0; i < 2; i++) {
    pthread_create(&threads[i], NULL, srv_side_handle, &sides[i]);
  }

  // signal to sshnpd that we are done
  fprintf(stderr, "%s\n", SRV_COMPLETION_STRING);

  pthread_t tid;
  int retval = 0;
  for (int i = 0; i < 2; i++) {
    read(fds[0], &tid, sizeof(pthread_t));

    res = pthread_join(tid, (void *)&retval);
    if (res != 0) {
      atclient_atlogger_log(TAG, INFO,
                            "Joining pthread %l failed with code: %l\n",
                            threads[i], res);
      break;
    }
    atclient_atlogger_log(TAG, INFO, "pthread %l exited with code: %l\n",
                          threads[i], retval);
    if (retval != 0) {
      break;
    }
  }

  if (res != 0 || retval != 0) {
    for (int i = 0; i < 2; i++) {
      if (pthread_cancel(threads[i]) != 0) {
        atclient_atlogger_log(TAG, INFO, "Failed to cancel thread: %l\n",
                              threads[i]);
      }
    }
  }

  close(fds[0]);
  close(fds[1]);

  return 0;
}
