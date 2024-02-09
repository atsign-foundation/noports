#ifndef SIDE_H
#define SIDE_H
#include <MbedTLS/net_sockets.h>
#include <netdb.h>
#include <srv/params.h>
#include <srv/stream.h>

typedef struct _side_hints_t side_hints_t;
typedef struct _side_t side_t;

struct _side_hints_t {
  const bool is_side_a;
  const bool is_server;
  const char *host;
  const uint16_t port;
  const chunked_transformer_t *transformer;
};

struct _side_t {
  // From hints
  const bool is_side_a;
  const bool is_server;
  const char *host;
  const uint16_t port;
  const chunked_transformer_t *transformer;

  // During init
  mbedtls_net_context *socket;
  side_t *other;
  int main_pipe[2];

  // Server state (null when is_server is false)
  mbedtls_net_context **connections;
  int connection_count;
  int connection_capacity;
};

int srv_side_init(const side_hints_t *hints, side_t *side);
void srv_link_sides(side_t *side_a, side_t *side_b, int fds[2]);
void srv_side_free(side_t *side);

void *srv_side_handle(void *side);

#endif
