#ifndef SRV_H
#define SRV_H
#include <netdb.h>
#include <srv/params.h>
#include <srv/stream.h>

typedef struct _side_t side_t;
struct _side_t {
  bool is_side_a;
  bool is_server;
  const char *auth_string;
  aes_transformer_t *transformer;
  int sock_fd;

  pthread_mutex_t *mutex;  // This mutex is used to lock things below it
  int *connected_fd_count; // Number of connected clients
  int **connected_fd;      // List of connected client pointers
  struct _side_t *other_side;
};

int run_srv(srv_params_t *params);

int socket_to_socket(const srv_params_t *params, const char *auth_string,
                     aes_transformer_t *encrypter,
                     aes_transformer_t *decrypter);

int server_to_socket(const srv_params_t *params, const char *auth_string,
                     aes_transformer_t *encrypter,
                     aes_transformer_t *decrypter);

void *handle_single_connection(void *side);

int init_socket_for_side(const char *host, const uint16_t port, side_t *side);
#endif
