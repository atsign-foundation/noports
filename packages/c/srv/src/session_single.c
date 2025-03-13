#include "authenticate.h"
#include "session.h"
#include "srv/params.h"
#include <pthread.h>

struct session create_session_single(struct srv_params params) {
  struct session session = (struct session){
      .type = session_type_unset, .single = session_single_initializer};
  struct channel *channel = &session.single.channel;

  // create the io
  channel->io[0] = create_channel_io_local(params);
  if (channel->io[0] == NULL) {
    return session;
  }

  channel->io[1] = create_channel_io_remote(params);
  if (channel->io[1] == NULL) {
    return session;
  }

  link_channel(channel);

  channel->pthread_mode = pthread_mode_wait;
  session.type = session_type_single;
  return session;
}

// TODO fix free management
int run_session_single(struct srv_params params, struct session session) {
  // connect and auth the remote side first to avoid timeouts
  if (session.type != session_type_single) {
    return 1;
  }

  struct channel *channel = &session.single.channel;

  int ret;
  struct channel_io *remote = NULL;
  struct channel_io *local = NULL;

  // * connect remote
  ret = create_channel_io_session(channel->io[1], &remote);
  if (ret != 0) {
    return ret;
  }

  // swap remote channel_io with the session's channel_io
  bool free_remote = false;
  if (channel->io[1] != remote) {
    struct channel_io *temp = remote;
    remote = channel->io[1];
    channel->io[1] = temp;
    free_remote = true;
  }

  // * authenticate remote
  ret = authenticate_remote(params, channel->io[1]);
  if (ret != 0) {
    return ret;
  }

  // * connect local
  ret = create_channel_io_session(channel->io[0], &local);
  if (ret != 0) {
    free_channel_io(channel->io[1]);
    return ret;
  }

  // swap local channel_io with the session's channel_io
  bool free_local = false;
  if (channel->io[0] != local) {
    struct channel_io *temp = local;
    local = channel->io[0];
    channel->io[0] = temp;
    free_local = true;
  }

  // * authenticate local
  ret = authenticate_local(params, channel->io[0]);
  if (ret != 0) {
    free_channel_io(channel->io[0]);
    free_channel_io(channel->io[1]);
    return ret;
  }

  // setup transformers
  ret = create_remote_to_local_channel_transformer(
      params, &channel->sinks[0].transformer);
  if (ret != 0) {
    free_channel_io(channel->io[0]);
    free_channel_io(channel->io[1]);
    if (free_local)
      free_channel_io(local);
    if (free_remote)
      free_channel_io(remote);
    return ret;
  }
  ret = create_local_to_remote_channel_transformer(
      params, &channel->sinks[1].transformer);

  if (ret != 0) {
    channel->sinks[0].transformer->free(channel->sinks[0].transformer);
    free_channel_io(channel->io[0]);
    free_channel_io(channel->io[1]);
    if (free_local)
      free_channel_io(local);
    if (free_remote)
      free_channel_io(remote);
    return ret;
  }

  ret = start_channel(channel, pthread_mode_wait);

  if (free_local)
    free_channel_io(local);
  if (free_remote)
    free_channel_io(remote);

  return ret;
}
