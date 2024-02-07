#include "srv/socket_to_socket.h"
#include "srv/params.h"
#include "srv/srv.h"
#include "srv/stream.h"
#include <atlogger.h>
#include <srv/side.h>

#define TAG "srv - socket_to_socket"
int socket_to_socket(const srv_params_t *params, const char *auth_string,
                     aes_transformer_t *encrypter,
                     aes_transformer_t *decrypter) {
  side_t side_a, side_b;
  side_hints_t hints_a = {1, 0, NULL, params->local_port, NULL};
  side_hints_t hints_b = {0, 0, params->host, params->port, auth_string};

  atclient_atlogger_log(TAG, INFO, "Initializing connection for side a\n");
  int res = srv_side_init(&hints_a, &side_a);
  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR,
                          "Failed to initialize connection for side a\n");
    return res;
  }

  atclient_atlogger_log(TAG, INFO, "Initializing connection for side b\n");
  res = srv_side_init(&hints_b, &side_b);
  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR,
                          "Failed to initialize connection for side b\n");
    return res;
  }

  srv_link_sides(&side_a, &side_b);

  atclient_atlogger_log(TAG, INFO, "Starting threads\n");
  pthread_t thread_a, thread_b;

  pthread_create(&thread_a, NULL, srv_side_handle, &side_a);
  pthread_create(&thread_b, NULL, srv_side_handle, &side_b);

  pthread_join(thread_a, NULL);
  pthread_join(thread_b, NULL);

  return 0;
}
