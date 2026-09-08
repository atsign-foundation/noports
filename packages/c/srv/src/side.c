#include "srv/side.h"
#include "srv/srv.h"
#include <atchops/base64.h>
#include <atlogger/atlogger.h>
#include <mbedtls/net_sockets.h>
#include <netdb.h>
#include <pthread.h>
#include <srv/params.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

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
    atlogger_log(TAG, INFO, "Doing tcp connect to %s:%s\n", side->host, service);
    int res = mbedtls_net_connect(&side->socket, side->host, service, MBEDTLS_NET_PROTO_TCP);
    if (res != 0) {
      mbedtls_net_free(&side->socket);
      if (res == MBEDTLS_ERR_NET_SOCKET_FAILED) {
        atlogger_log(TAG, ERROR, "Failed: tcp connect - socket failed\n");
      } else if (res == MBEDTLS_ERR_NET_UNKNOWN_HOST) {
        atlogger_log(TAG, ERROR, "Failed: tcp connect - unknown host\n");
      } else if (res == MBEDTLS_ERR_NET_CONNECT_FAILED) {
        atlogger_log(TAG, ERROR, "Failed: tcp connect - connect failed\n");
      }
      return res;
    }
  } else {
    atlogger_log(TAG, INFO, "Doing tcp bind\n");
    int res = mbedtls_net_bind(&side->socket, side->host, service, MBEDTLS_NET_PROTO_TCP);
    if (res != 0) {
      mbedtls_net_free(&side->socket);
      atlogger_log(TAG, ERROR, "Failed: tcp bind\n");
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

  // Stack buffers, deliberately: socket_to_socket terminates this thread with
  // pthread_cancel when the other side finishes, so anything heap-allocated
  // here would leak on every connection teardown (the cancel lands in
  // mbedtls_net_recv, before any free could run)
  unsigned char buffer[BUFFER_LEN];
  unsigned char output[BUFFER_LEN];
  memset(buffer, 0, BUFFER_LEN);

  if (s->is_server == 0) {
    size_t len;
    int res;
    while ((res = mbedtls_net_recv(&s->socket, buffer, READ_LEN)) > 0) {
      len = res;

      unsigned char *to_send = buffer;
      if (s->transformer != NULL) {
        memset(output, 0, BUFFER_LEN);
        res = (int)s->transformer->transform(s->transformer, len, buffer, output);
        if (res != 0) {
          atlogger_log(tag, ERROR, "Error transforming buffer of len: %zu", len);
          break;
        }
        to_send = output;
      }

      if (s->other->is_server == 0) {
        bool send_failed = false;
        size_t sent = 0;
        while (sent < len) {
          res = mbedtls_net_send(&s->other->socket, to_send + sent, len - sent);
          if (res == MBEDTLS_ERR_SSL_WANT_WRITE) {
            continue; // interrupted (EINTR) - retry the send
          }
          if (res < 0) {
            atlogger_log(tag, ERROR, "Error sending data: %d\n", res);
            send_failed = true;
            break;
          }
          sent += res;
        }
        if (send_failed) {
          // The peer socket is dead; silently continuing would keep consuming
          // from our own socket and drop every subsequent chunk. Exit the
          // relay loop so teardown runs.
          break;
        }
      } else {
        halt_if_cant_bind_local_port();
      }
      memset(buffer, 0, BUFFER_LEN);
    }
    // Deliberately do NOT close s->socket here: the peer thread may be
    // concurrently writing to it (s->other->socket from its point of view),
    // and in multi mode a close here lets the kernel reuse the fd number for
    // another session's socket - the peer's next write would then inject this
    // session's data into an unrelated session. socket_to_socket's teardown
    // closes both sockets via srv_side_free only after both threads have been
    // joined, which is the only safe point.
  } else {
  }

  // Notify the main thread that we are done so it will know to clean up
  atlogger_log(tag, DEBUG, "Exiting side thread\n");
  pthread_t t = pthread_self();
  write(s->main_pipe[1], &t, sizeof(pthread_t));

  // Exit this thread
  pthread_exit(NULL);
}
