#include "atlogger/atlogger.h"
#include "authenticate.h"
#include "session.h"
#include <srv/params.h>

#define TAG "session_stacking"
struct session create_session_stacking(struct srv_params params) {
  struct session session = (struct session){
      .type = session_type_unset, .stacking = session_stacking_initializer};
  struct channel_io *local = &session.stacking.local;

  local = create_channel_io_local(params);
  if (local == NULL) {
    atlogger_log(
        TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
        "Failed to create session, creation of local channel io failed\n");
    return session;
  }

  struct channel_io *remote = &session.stacking.remote;
  remote = create_channel_io_remote(params);
  if (remote == NULL) {
    atlogger_log(
        TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
        "Failed to create session, creation of remote channel io failed\n");
    free_channel_io(local);
    return session;
  }

  session.type = session_type_stacking;
  return session;
}

int run_session_stacking(struct srv_params params, struct session session) {
  // TODO: deal with timeouts
  int ret = 0;
  bool should_continue = true;
  while (should_continue) {
    struct channel_io *binds[2] = {NULL, NULL};
    if (session.stacking.remote.type == channel_io_type_bind) {
      binds[0] = &session.stacking.remote;
    }
    if (session.stacking.local.type == channel_io_type_bind) {
      binds[1] = &session.stacking.local;
    }

    struct channel_io *remote = NULL;
    struct channel_io *local = NULL;
    for (int i = 0; i < 2; i++) {
      if (binds[i] == NULL)
        continue;
      struct channel_io *temp = NULL;
      ret = binds[i]->accept(binds[i], temp);
      if (ret != 0)
        continue;
      if (i == 0) {
        remote = temp;
      } else {
        local = temp;
      }
    }

    if (remote == NULL && local == NULL)
      continue;

    if (remote == NULL) {

      // connect remote
      ret = create_channel_io_session(&session.stacking.remote, &remote);
      if (ret != 0) {
        free_channel_io(local);
        // TODO what do here
      }
    } else {
      // connect local
      ret = create_channel_io_session(&session.stacking.local, &local);
      if (ret != 0) {
        free_channel_io(remote);
        // TODO what do here
      }
    }

    ret = authenticate_remote(params, remote);
    if (ret != 0) {
      // TODO
    }
    ret = authenticate_local(params, local);
    if (ret != 0) {
      // TODO
    }

    struct channel channel = channel_initializer;
    channel.io[0] = local;
    channel.io[1] = remote;

    link_channel(&channel);

    ret = create_remote_to_local_channel_transformer(
        params, &channel.sinks[0].transformer);
    if (ret != 0) {
      // TODO
    }

    ret = create_local_to_remote_channel_transformer(
        params, &channel.sinks[1].transformer);
    if (ret != 0) {
      // TODO
    }

    ret = start_channel(&channel, pthread_mode_detach);
    if (ret != 0) {
      // TODO
    }
  }

  return ret;
}
