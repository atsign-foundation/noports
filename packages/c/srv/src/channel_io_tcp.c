#include "channel_io_tcp.h"
#include "channel_io.h"
#include "ring.h"
#include <atlogger/atlogger.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <stdbool.h>
#include <sys/socket.h>
#include <unistd.h>

#define TAG "channel_io_tcp"
#define TCP_BACKLOG_SIZE 32

// TODO log errno errors in this file

// General methods
static void _free_socket(struct channel_io *self);
static void _free_info(struct channel_io *self);

// RW methods
static int _send(struct channel_io *self, const unsigned char *const buffer,
                 size_t len);
static int _recv(struct channel_io *self, unsigned char *buffer, size_t *len);

// Bind methods
static int _accept(struct channel_io *bind, struct channel_io *self);
// Connect methods
static int _connect(struct channel_io *ctx,

                    struct channel_io *self);

// Macros to reduce repetition in this file
//
#define unset_initializer                                                      \
  (struct channel_io) { .type = channel_io_type_unset, }

#define initialize_bind(channel_io)                                            \
  {                                                                            \
    channel_io->free = &_free_socket;                                          \
    channel_io->accept = &_accept;                                             \
    channel_io->type = channel_io_type_bind;                                   \
  }

#define initialize_connect(channel_io)                                         \
  {                                                                            \
    channel_io->free = &_free_info;                                            \
    channel_io->connect = &_connect;                                           \
    channel_io->type = channel_io_type_connect;                                \
  }

#define initialize_rw(channel_io)                                              \
  {                                                                            \
    channel_io->free = &_free_socket;                                          \
    channel_io->send = &_send;                                                 \
    channel_io->recv = &_recv;                                                 \
    channel_io->type = channel_io_type_rw;                                     \
  };

#define setup_method                                                           \
  if (self == NULL) {                                                          \
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,                            \
                 "cannot execute %s, self is null\n", __FUNCTION__);           \
    return 1;                                                                  \
  }                                                                            \
  struct channel_io_tcp_socket *tcp = (struct channel_io_tcp_socket *)self

int create_channel_io_tcp_connect_context(struct channel_io *self,
                                          const char *host, const char *port) {
  if (self == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "cannot execute %s, self is null\n", __FUNCTION__);
    return 1;
  }
  struct channel_io_tcp_info *info = (struct channel_io_tcp_info *)self;
  *self = unset_initializer;

  size_t host_size = strlen(host) + 1;
  info->host = malloc(sizeof(char) * host_size);
  if (info->host == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to allocate memory for host context\n");
    return 1;
  }
  memcpy(info->host, host, host_size);

  size_t port_size = strlen(host) + 1;
  info->port = malloc(sizeof(char) * port_size);
  if (info->port == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to allocate memory for port context\n");
    free(info->host);
    return 1;
  }
  memcpy(info->port, port, port_size);

  initialize_connect(self);
  return 0;
}

int bind_channel_io_tcp(struct channel_io *self, const char *host,
                        const char *port) {
  setup_method;
  *self = unset_initializer;

  struct addrinfo hints = {0};
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_flags = AI_PASSIVE | AI_ADDRCONFIG;
  struct addrinfo *addr;

  int ret = getaddrinfo(host, port, &hints, &addr);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Hostname lookup failed for %s:%s\n", host, port);
    return ret;
  }

  tcp->sock = socket(addr->ai_family, addr->ai_socktype, addr->ai_protocol);
  if (tcp->sock < 0) {
    freeaddrinfo(addr);
    tcp->sock = 0;
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create socket\n");
    return tcp->sock;
  }

  ret = fcntl(tcp->sock, F_SETFL, O_NONBLOCK);
  if (ret == -1) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to set socket to non-blocking mode\n");
    close(tcp->sock);
    tcp->sock = 0;
    freeaddrinfo(addr);
  }

  int reuse = 1;
  // Allow address reuse
  setsockopt(tcp->sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

  ret = bind(tcp->sock, addr->ai_addr, addr->ai_addrlen);
  freeaddrinfo(addr);
  if (ret < 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to bind to: %s:%s\n", host, port);
    close(tcp->sock);
    tcp->sock = 0;
    return ret;
  }
  initialize_bind(self);

  ret = listen(tcp->sock, TCP_BACKLOG_SIZE);
  if (ret < 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to listen on: %s:%s\n", host, port);
    close(tcp->sock);
    tcp->sock = 0;
    self->type = channel_io_type_unset;
    return ret;
  }

  return 0;
}

static int _accept(struct channel_io *self, struct channel_io *accepted) {
  setup_method;

  if (accepted == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "cannot accept tcp connection, accepted io is null\n");
    return 2;
  }

  if (self->type != channel_io_type_bind) {
    atlogger_log(
        TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
        "cannot accept tcp connection, bind io is not of type tcp_bind\n");
    return 3;
  }
  *self = unset_initializer;

  struct sockaddr address;
  socklen_t addrLength = sizeof(address);
  int sock = accept(tcp->sock, &address, &addrLength);
  if (sock == EWOULDBLOCK) {
    // noop - no connections to accept
    return 0;
  } else if (sock < 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to accept the connection\n");
    return sock;
  }

  accepted = malloc(sizeof(struct channel_io_tcp_socket));
  if (accepted == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to allocate the channel_io_tcp connection\n");
    return ENOMEM;
  }

  struct channel_io_tcp_socket *accepted_tcp =
      (struct channel_io_tcp_socket *)accepted;
  accepted_tcp->sock = sock;

  return 0;
}

static int _connect(struct channel_io *ctx, struct channel_io *self) {
  setup_method;
  struct addrinfo hints = {0};
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_flags = AI_ADDRCONFIG;

  struct addrinfo *addr;
  char *host = ((struct channel_io_tcp_info *)ctx)->host;
  char *port = ((struct channel_io_tcp_info *)ctx)->port;
  int ret = getaddrinfo(host, port, &hints, &addr);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Hostname lookup failed for %s:%s\n", host, port);
    return ret;
  }

  struct sockaddr_in *addrinfo = (struct sockaddr_in *)addr->ai_addr;

  tcp->sock =
      socket(addrinfo->sin_family, addr->ai_socktype, addr->ai_protocol);
  if (tcp->sock < 0) {
    freeaddrinfo(addr);
    tcp->sock = 0;
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create socket\n");
    return tcp->sock;
  }

  ret = connect(tcp->sock, (struct sockaddr *)addrinfo, addr->ai_addrlen);
  freeaddrinfo(addr);
  if (ret != 0) {
    close(tcp->sock);
    tcp->sock = 0;
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to connect to: %s:%s\n", host, port);
    return ret;
  }
  initialize_rw(self);
  return 0;
}

static int _send(struct channel_io *self, const unsigned char *const buffer,
                 size_t len) {
  setup_method;

  ssize_t ret;
  size_t total_sent = 0;
  do {
    ret = write(tcp->sock, buffer, len);
    if (ret > 0) {
      total_sent += ret;
    }
  } while (total_sent < len || errno == EINTR);

  if (ret < 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Error writing to tcp io: %s\n", strerror(errno));
    return ret;
  }
  return 0;
}

static int _recv(struct channel_io *self, unsigned char *buffer, size_t *len) {
  setup_method;
  ssize_t ret;
  do {
    ret = read(tcp->sock, buffer, ring_buffer_size);
  } while (errno == EINTR);

  if (ret < 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Error reading from fill io into sink: %s\n", strerror(errno));
    return ret;
  }

  *len = ret;
  return 0;
}

static void _free_socket(struct channel_io *self) {
  if (self == NULL || self->type == channel_io_type_unset) {
    return;
  }
  struct channel_io_tcp_socket *tcp = (struct channel_io_tcp_socket *)self;
  close(tcp->sock);
}

static void _free_info(struct channel_io *self) {
  if (self == NULL || self->type == channel_io_type_unset) {
    return;
  }
  struct channel_io_tcp_info *info = (struct channel_io_tcp_info *)self;
  free(info->host);
  free(info->port);
}
