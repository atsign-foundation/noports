#include "srv/side.h"
#include "srv/srv.h"
#include <MbedTLS/net_sockets.h>
#include <atchops/base64.h>
#include <atlogger.h>
#include <netdb.h>
#include <srv/params.h>
#include <srv/stream.h>
#include <string.h>
#include <sys/socket.h>

#define TAG "srv - side"
#define TAG_A "srv - side a"
#define TAG_B "srv - side b"

int srv_side_init(const side_hints_t *hints, side_t *side) {
  mbedtls_net_context *ctx = malloc(sizeof(mbedtls_net_context));
  mbedtls_net_init(ctx);

  memcpy(side, hints, sizeof(side_hints_t));

  // Convert port to string
  char service[MAX_PORT_LEN];
  snprintf(service, MAX_PORT_LEN, "%d", side->port);

  if (side->is_server == 0) {
    atclient_atlogger_log(TAG, INFO, "Doing tcp connect to %s:%s\n", side->host,
                          service);
    int res =
        mbedtls_net_connect(ctx, side->host, service, MBEDTLS_NET_PROTO_TCP);
    if (res != 0) {
      mbedtls_net_free(ctx);
      if (res == MBEDTLS_ERR_NET_SOCKET_FAILED) {
        atclient_atlogger_log(TAG, ERROR,
                              "Failed: tcp connect - socket failed\n");
      } else if (res == MBEDTLS_ERR_NET_UNKNOWN_HOST) {
        atclient_atlogger_log(TAG, ERROR,
                              "Failed: tcp connect - unknown host\n");
      } else if (res == MBEDTLS_ERR_NET_CONNECT_FAILED) {
        atclient_atlogger_log(TAG, ERROR,
                              "Failed: tcp connect - connect failed\n");
      }
      return res;
    }
  } else {
    atclient_atlogger_log(TAG, INFO, "Doing tcp bind\n");
    int res = mbedtls_net_bind(ctx, side->host, service, MBEDTLS_NET_PROTO_TCP);
    if (res != 0) {
      mbedtls_net_free(ctx);
      atclient_atlogger_log(TAG, ERROR, "Failed: tcp bind\n");
      return res;
    }
  }

  // store the context
  side->socket = ctx;
  return 0;
}

void srv_link_sides(side_t *side_a, side_t *side_b, int fds[2]) {
  side_a->other = side_b;
  side_a->main_pipe[0] = fds[0];
  side_a->main_pipe[1] = fds[1];
  side_b->other = side_a;
  side_b->main_pipe[0] = fds[0];
  side_b->main_pipe[1] = fds[1];
}

void srv_side_free(side_t *side) { mbedtls_net_free(side->socket); }

void *srv_side_handle(void *side) {
  side_t *s = (side_t *)side;

  const char *const tag = s->is_side_a ? TAG_A : TAG_B;
  unsigned char *buffer = malloc(MAX_BUFFER_LEN * sizeof(unsigned char));

  if (s->is_server == 0) {
    // rlen = received length
    // len = length (received or transformed)
    // slen = sent length
    size_t rlen, len, slen;

    while ((rlen = mbedtls_net_recv(s->socket, buffer, MAX_BUFFER_LEN)) > 0) {

      if (s->transformer != NULL) {
        atclient_atlogger_log(tag, INFO, "Transforming data\n");
        int res =
            (int)s->transformer->transform(s->transformer, buffer, rlen, &len);
        if (res != 0) {
          break;
        }
      } else {
        len = rlen;
      }

      if (s->other->is_server == 0) {
        slen = mbedtls_net_send(s->other->socket, buffer, len);
      } else {
        halt_if_cant_bind_local_port();
      }
      if (slen != len) {
        // How to handle this? We probably shouldn't just drop the connection
        atclient_atlogger_log(
            tag, ERROR,
            "Error sending data, expected to send %lu bytes, only sent %lu\n",
            len, slen);
        break;
      }
    }
    free(buffer);
    mbedtls_net_close(s->socket);
  } else {
  }
  pthread_exit(NULL);
}
