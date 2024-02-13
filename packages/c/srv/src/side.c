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
  // Is it a bit redundant to use a separate struct for the predefined values in
  // the side struct? yes... but it is easier to tell what you should set vs let
  // this function set
  memcpy(side, hints, sizeof(side_hints_t));
  mbedtls_net_init(&side->socket);

  // Convert port to string
  char service[MAX_PORT_LEN];
  snprintf(service, MAX_PORT_LEN, "%d", side->port);

  if (side->is_server == 0) {
    atclient_atlogger_log(TAG, INFO, "Doing tcp connect to %s:%s\n", side->host, service);
    int res = mbedtls_net_connect(&side->socket, side->host, service, MBEDTLS_NET_PROTO_TCP);
    if (res != 0) {
      mbedtls_net_free(&side->socket);
      if (res == MBEDTLS_ERR_NET_SOCKET_FAILED) {
        atclient_atlogger_log(TAG, ERROR, "Failed: tcp connect - socket failed\n");
      } else if (res == MBEDTLS_ERR_NET_UNKNOWN_HOST) {
        atclient_atlogger_log(TAG, ERROR, "Failed: tcp connect - unknown host\n");
      } else if (res == MBEDTLS_ERR_NET_CONNECT_FAILED) {
        atclient_atlogger_log(TAG, ERROR, "Failed: tcp connect - connect failed\n");
      }
      return res;
    }
  } else {
    atclient_atlogger_log(TAG, INFO, "Doing tcp bind\n");
    int res = mbedtls_net_bind(&side->socket, side->host, service, MBEDTLS_NET_PROTO_TCP);
    if (res != 0) {
      mbedtls_net_free(&side->socket);
      atclient_atlogger_log(TAG, ERROR, "Failed: tcp bind\n");
      return res;
    }
  }

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

void srv_side_free(side_t *side) { mbedtls_net_free(&side->socket); }
void *srv_side_handle(void *side) {
  side_t *s = (side_t *)side;

  const char *const tag = s->is_side_a ? TAG_A : TAG_B;

  unsigned char *buffer = malloc(BUFFER_LEN * sizeof(unsigned char));

  if (s->is_server == 0) {
    size_t len, slen;
    int res;
    while ((len = mbedtls_net_recv(&s->socket, buffer, READ_LEN)) > 0) {
      if (res < 0) {
        atclient_atlogger_log(tag, ERROR, "Error reading data: %d", len);
        break;
      } else {
        len = res;
      }
      atclient_atlogger_log(tag, INFO, "Read %d bytes \n", len);

      if (s->transformer != NULL) {
        uft8_safe_log(tag, DEBUG, buffer, len);
        atclient_atlogger_log(tag, DEBUG, "Transforming data:\n");
        res = (int)s->transformer->transform(s->transformer, buffer, &len);
        if (res != 0) {
          break;
        }
        uft8_safe_log(tag, DEBUG, buffer, len);
      }

      if (s->other->is_server == 0) {
        res = mbedtls_net_send(&s->other->socket, buffer, len);
        if (res < 0) {
          atclient_atlogger_log(tag, ERROR, "Error sending data: %d", res);
          break;
        } else {
          slen = res;
        }
      } else {
        halt_if_cant_bind_local_port();
      }
      if (slen < len) {
        // TODO: implement retries
        atclient_atlogger_log(tag, ERROR, "Error sending data, expected to send %lu bytes, only sent %lu\n", len, slen);
        break;
      }
    }
    free(buffer);
    mbedtls_net_close(&s->socket);
  } else {
  }

  // Notify the main thread that we are done so it will know to clean up
  atclient_atlogger_log(tag, DEBUG, "Exiting side thread\n");
  pthread_t t = pthread_self();
  write(s->main_pipe[1], &t, sizeof(pthread_t));

  // Exit this thread
  pthread_exit(NULL);
}
