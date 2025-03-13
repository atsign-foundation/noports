#include "run_socket_to_socket.h"
#include "channel.h"
#include "channel_io_tcp.h"
#include "channel_transformer.h"
#include "session.h"
#include <atlogger/atlogger.h>

#define TAG "socket_to_socket"

int run_socket_to_socket(const struct srv_params *params,
                         struct session *_session) {
  int ret;
  if (params == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "params is a required argument\n");
    return 1;
  }
  if (_session == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "session is a required argument\n");
    return 1;
  }

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

  struct single_session *session = &_session->single;

  *session = single_session_initializer;
  struct channel_sink *sink0 = &session->channel.sinks[0]; // decrypt sink
  struct channel_sink *sink1 = &session->channel.sinks[1]; // encrypt sink

  // setup transformer
  ret = create_transform_ctx(params->remote_transformer, &sink0->transform_ctx,
                             &sink1->transform_ctx);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create transform context\n");
    return ret;
  }

  // setup remote io
  struct channel_io *remote = session->channel.io + 1;
  ret = connect_channel_io_tcp(remote, params->host, params->port);
  if (ret != 0) {
    free_channel(&session->channel);
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create the remote tcp client\n");
    return ret;
  }

  // authenticate remote connection
  if (remote_auth_payload != NULL) {
    ret = send_channel_io_tcp(remote, (unsigned char *)remote_auth_payload,
                              (uint16_t)strlen(remote_auth_payload));
    if (ret != 0) {
      free_channel(&session->channel);
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to authenticate the remote tcp client\n");
      return ret;
    }
  }

  // setup local io
  struct channel_io *local = session->channel.io + 0;
  ret = connect_channel_io_tcp(local, params->local_host, params->local_port);
  if (ret != 0) {
    free_channel(&session->channel);
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create the local tcp client\n");
    return ret;
  }

  // link sinks to io
  sink0->io[0] = remote; // fill on decrypt side from remote
  sink0->io[1] = local;  // drain on decrypt side to local
  sink1->io[0] = local;  // fill on encrypt side from local
  sink1->io[1] = remote; // drain on encrypt side to remote

  // We've setup as much as we can, the last thing to do is spawn the channel
  // controller and let it do it's thing
  pthread_t tid;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, run_channel_stacksize);

  struct pthread_handle handle = pthread_handle_initializer;
  session->channel.pthread_handle = &handle;
  session->channel.pthread_mode = pthread_mode_wait;

  ret = pthread_create(&tid, &attr, run_channel, &session->channel);
  pthread_attr_destroy(&attr);

  if (ret != 0) {
    free_channel(&session->channel);
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to spawn the channel manager thread\n");
    return ret;
  }

  pthread_t otid = pthread_handle_wait(&handle);
  if (tid != otid) {
    // big uhoh - there should only be one thread
    // this should never happen, so we must crash as something is very wrong
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "State error: unexpected thread resolution from "
                 "run_channel\n\t(expected: %p, actual: %p)\n",
                 tid, otid);
    exit(1);
  }
  free_pthread_handle(&handle);

  int pthread_ret;
  ret = pthread_join(otid, (void *)&pthread_ret);
  if (ret == 0) {
    return pthread_ret; // return ret code of the run_channel
  } else {
    return ret; // if we failed to join, something went wrong
  }
}
