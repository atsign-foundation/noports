#include "run_server_to_socket_multi.h"
#include "channel_bitmask.h"
#include "constants.h"
#include <atlogger/atlogger.h>
#include <unistd.h>

#define TAG "server_to_socket"

int run_server_to_socket_multi(const struct srv_params *params,
                               struct control_session *session) {
  int ret;

  *session = control_session_initializer;
  struct channel_io *control = &session->control_io;

  char *remote_auth_payload;
  if (params->remote_auth == srv_auth_type_payload) {
    remote_auth_payload = getenv("REMOTE_AUTH_PAYLOAD");
    if (remote_auth_payload == NULL) {
      remote_auth_payload = getenv("RV_AUTH");
      if (remote_auth_payload == NULL) {
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Remote authentication is set to payload, but environment "
                     "variable not passed. See help.\n");
        return 1;
      }
    }
  }

  ret = bind_channel_io_tcp(control, params->local_host, params->local_port);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to bind the local tcp server\n");
    return ret;
  }

  time_t last_connection_closed_at = time(NULL);
  struct channel_bitmask channel_bitmask = channel_bitmask_initializer;
  while (channel_bitmask_is_not_empty(&channel_bitmask) &&
         time(NULL) - last_connection_closed_at < params->timeout) {
    // the channel itself will be copied into the channel manager thread
    // we will drop this from the stack here, but channel_bitmask will track
    // for closure of the channels. Once all have closed we can handle timeouts
    struct channel channel = channel_initializer;
    // setup local io
    struct channel_io *local = channel.io + 0;
    ret = accept_channel_io_tcp(control, local);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to accept incoming tcp connection\n");
      free_channel(&channel);
      continue;
    }

    // handle no new sockets to connect
    if (local->type == unset_io_type) {
      free_channel(&channel);
      if (channel_bitmask_is_not_empty(&channel_bitmask)) {
        // reset timer if something is still open
        last_connection_closed_at = time(NULL);
      }
      continue;
    }

    // wait until a handle becomes available
    int channel_handle = 0;
    int backoff = 10000; // 10 ms
    do {
      if (channel_handle == -1) {
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                     "Maximum number of channels reached, will try to get a "
                     "handle again in %d ms\n",
                     backoff / 1000);
        usleep(backoff);
        if (backoff < 1000000) { // up to 1 second
          backoff += 10000;      // 10 ms
        }
      }
      channel_handle = channel_bitmask_find_slot(&channel_bitmask);
    } while (channel_handle == -1);
    ret = channel_bitmask_open(&channel_bitmask, channel_handle);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Unrecoverable error: channel channel_bitmask_open called "
                   "while channel is in use\n");
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Please contact support for assistance\n");
      free_channel(&channel);
      free_channel_io(control);
      return 1;
    }

    // setup remote io
    struct channel_io *remote = channel.io + 1;
    ret = connect_channel_io_tcp(remote, params->host, params->port);
    if (ret != 0) {
      free_channel(&channel);
      continue;
    }

    if (remote_auth_payload != NULL) {
      ret = send_channel_io_tcp(remote, (unsigned char *)remote_auth_payload,
                                (uint16_t)strlen(remote_auth_payload));
      if (ret != 0) {
        free_channel(&channel);
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to authenticate the remote tcp client\n");
        continue;
      }
    }

    // TODO: cut new AES key / IV
    // TODO  send control message

    // setup transformer
    struct channel_sink *sink0 = &channel.sinks[0]; // decrypt sink
    struct channel_sink *sink1 = &channel.sinks[1]; // encrypt sink
    ret = create_transform_ctx(params->remote_transformer,
                               &sink0->transform_ctx, &sink1->transform_ctx);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to create channel transform context\n");
      free_channel(&channel);
      continue;
    }

    pthread_t tid;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, run_channel_stacksize);

    struct pthread_handle thread_handle = pthread_handle_initializer;
    channel.pthread_handle = &thread_handle;
    channel.pthread_mode = pthread_mode_detach;
    channel.channel_bitmask = &channel_bitmask;
    channel.channel_handle = channel_handle;

    ret = pthread_create(&tid, &attr, run_channel, &channel);
    pthread_attr_destroy(&attr);

    if (ret != 0) {
      free_channel(&channel);
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to spawn the channel manager thread\n");
      continue;
    }

    pthread_t otid = pthread_handle_wait(&thread_handle);
    if (tid != otid) {
      // big uhoh - there should only be one thread
      // this should never happen, so we must crash as something is very wrong
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "State error: unexpected thread resolution from "
                   "run_channel\n\t(expected: %p, actual: %p)\n",
                   tid, otid);
      exit(1);
    }
    free_pthread_handle(&thread_handle);

    // reset timer
    last_connection_closed_at = time(NULL);
    // dont free channel on success, will be handled by the channel manager
  }

  // timed out, handle cleanup
  free_channel_io(control);
  return 0;
}
