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
  char service[MAX_PORT_DIGIT_COUNT];
  snprintf(service, MAX_PORT_DIGIT_COUNT, "%d", side->port);

  if (side->is_server == 0) {
    atclient_atlogger_log(TAG, INFO, "Doing tcp connect to %s:%s\n", side->host,
                          service);
    int res =
        mbedtls_net_connect(ctx, side->host, service, MBEDTLS_NET_PROTO_TCP);
    if (res != 0) {
      mbedtls_net_free(ctx);
      atclient_atlogger_log(TAG, ERROR, "Failed: tcp connect\n");
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

void srv_link_sides(side_t *side_a, side_t *side_b) {
  side_a->other = side_b;
  side_b->other = side_a;
}

void srv_side_free(side_t *side) { mbedtls_net_free(side->socket); }

void *srv_side_handle(void *side) {
  side_t *s = (side_t *)side;

  const char *const tag = s->is_side_a ? TAG_A : TAG_B;
  unsigned char *buffer = malloc(MAX_BUFFER_LEN * sizeof(unsigned char));

  if (s->is_server == 0) {
    // TODO: make this proper code
    int len, slen;

    atclient_atlogger_log(tag, INFO, "Starting handler\n");
    while ((len = mbedtls_net_recv_timeout(s->socket, buffer, MAX_BUFFER_LEN,
                                           RECV_TIMEOUT)) > 0) {
      atclient_atlogger_log(tag, INFO, "Received data | len: %d\n", len);
      atclient_atlogger_log(tag, INFO, "Data: %s\n", buffer);

      // if (side->transformer != NULL) {
      //   atclient_atlogger_log(tag, INFO, "Transforming data\n");
      //   side->transformer->transform(side->transformer, buffer, len);
      // }

      if (s->other->is_server == 0) {
        slen = mbedtls_net_send(s->other->socket, buffer, len);
      } else {
        verify_bind_local_port();
      }
      if (slen != len) {
        atclient_atlogger_log(
            tag, ERROR,
            "Error sending data, expected to send %d bytes, only sent %d\n",
            len, slen);
        break;
      }
      atclient_atlogger_log(tag, INFO, "Sent data\n");
    }
  } else {
  }
  pthread_exit(NULL);
}
