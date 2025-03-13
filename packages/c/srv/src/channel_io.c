#include "channel_io.h"
#include "atlogger/atlogger.h"
#include "channel_io_tcp.h"
#include <stdlib.h>

#define TAG "channel_io"

struct channel_io *create_channel_io_remote(struct srv_params params) {
  struct channel_io *io;

  // TODO  logging errors
  int ret;
  switch (params.remote_io) {

  case srv_io_type_tcp_client:
    io = malloc(sizeof(struct channel_io_tcp_info));
    if (io == NULL) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to allocate remote channel_io_tcp_info\n");
      return NULL;
    }
    ret = create_channel_io_tcp_connect_context(io, params.host, params.port);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to create remote channel_io_tcp connect context\n");
      return NULL;
    }
    break;

  case srv_io_type_tcp_bind:
    io = malloc(sizeof(struct channel_io_tcp_socket));
    if (io == NULL) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to allocate remote channel_io_tcp_socket\n");
      return NULL;
    }
    ret = bind_channel_io_tcp(io, params.host, params.port);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to bind remote channel_io_tcp\n");
      return NULL;
    }
    break;
  default:
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Unrecognized remote channel_io type\n");
    return NULL;
  }

  return io;
}

struct channel_io *create_channel_io_local(struct srv_params params) {
  struct channel_io *io;

  // TODO  logging errors
  int ret;
  switch (params.local_io) {

  case srv_io_type_tcp_client:
    io = malloc(sizeof(struct channel_io_tcp_info));
    if (io == NULL) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to allocate local channel_io_tcp_info\n");
      return NULL;
    }
    ret = create_channel_io_tcp_connect_context(io, params.local_host,
                                                params.local_port);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to create local channel_io_tcp connect context\n");
      return NULL;
    }
    break;

  case srv_io_type_tcp_bind:
    io = malloc(sizeof(struct channel_io_tcp_socket));
    if (io == NULL) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to allocate local channel_io_tcp_socket\n");
      return NULL;
    }
    ret = bind_channel_io_tcp(io, params.local_host, params.local_port);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to bind local channel_io_tcp\n");
      return NULL;
    }
    break;

  default:
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Unrecognized local channel_io type\n");
    return NULL;
  }

  return io;
}

// frees a heap allocated channel_io
void free_channel_io(struct channel_io *io) {
  if (io == NULL)
    return;
  io->free(io);
  free(io);
}

int create_channel_io_session(struct channel_io *creator,
                              struct channel_io **channel_io) {
  int ret;
  switch (creator->type) {
  case channel_io_type_unset:
    return 1;
  case channel_io_type_rw:
    *channel_io = creator;
    return 0;
  case channel_io_type_bind:
    // TODO: handle timeouts
    ret = creator->accept(creator, *channel_io);
    break;
  case channel_io_type_connect:
    ret = creator->connect(creator, *channel_io);
    break;
  }
  return ret;
}
