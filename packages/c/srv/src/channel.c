#include "channel.h"
#include "channel_sink.h"
#include "pthread_handle.h"
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>

#define TAG "channel"

static size_t calc_stacksize(size_t min) {
  size_t size = 1;
  int pagesize = getpagesize();
  while (size < min) {
    size *= pagesize;
  }
  return size;
}
#define run_channel_stacksize calc_stacksize(sizeof(void *) * 2) // 2 = 16 /8
#define run_channel_sink_stacksize                                             \
  calc_stacksize(sizeof(void *) * 4) // 4 = 32/8

static void *run_channel(void *_channel);

void free_channel(struct channel *channel) {
  free_pthread_handle(channel->pthread_handle);
  free_channel_sink(channel->sinks + 0);
  free_channel_sink(channel->sinks + 1);
  free_channel_io(channel->io[0]);
  free_channel_io(channel->io[1]);
}

void link_channel(struct channel *channel) {
  struct channel_sink *remote_to_local_sink = channel->sinks + 0;
  remote_to_local_sink->io[0] = channel->io[1];
  remote_to_local_sink->io[1] = channel->io[0];

  struct channel_sink *local_to_remote_sink = channel->sinks + 1;
  local_to_remote_sink->io[0] = channel->io[0];
  local_to_remote_sink->io[1] = channel->io[1];
}

int start_channel(struct channel *channel, enum pthread_mode mode) {
  pthread_t tid;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, run_channel_stacksize);

  struct pthread_handle handle = pthread_handle_initializer;
  channel->pthread_handle = &handle;
  channel->pthread_mode = mode;
  int ret = pthread_create(&tid, &attr, run_channel, &channel);

  if (ret != 0) {
    free_channel(channel);
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to spawn the channel manager thread\n");
    pthread_attr_destroy(&attr);
    return ret;
  }

  pthread_t otid = pthread_handle_wait(&handle);
  free_channel(channel);
  pthread_attr_destroy(&attr);
  if (tid != otid) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "State error: unexpected thread resolution from "
                 "run_channel\n\t(expected: %p, actual: %p)\n",
                 tid, otid);
    exit(1);
  }

  return 0;
}

// cleanup payload for pthread
struct channel_cleanup {
  struct channel *channel;
  pthread_t *threads;
  pthread_attr_t *attr;
  uint8_t num_threads;
};

// pthread functions
static void cancel_run_channel(void *_cleanup) {
  struct channel_cleanup *cleanup = (struct channel_cleanup *)_cleanup;

  for (uint8_t i = 0; i < cleanup->num_threads; i++) {
    pthread_cancel(cleanup->threads[i]);
  }
  for (uint8_t i = 0; i < cleanup->num_threads; i++) {
    pthread_join(cleanup->threads[i], NULL);
  }
  if (cleanup->channel->pthread_handle != NULL &&
      cleanup->channel->pthread_mode == pthread_mode_wait) {
    pthread_handle_signal(cleanup->channel->pthread_handle);
  }
  pthread_attr_destroy(cleanup->attr);
  free_channel(cleanup->channel);
}

static void *run_channel(void *_channel) {
  if (_channel == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Channel payload not provided\n");
    pthread_exit((void *)1);
  }

  // Make a copy of the channel in this scope
  struct channel channel;
  memcpy(&channel, _channel, sizeof(struct channel));
  if (channel.pthread_handle != NULL &&
      channel.pthread_mode == pthread_mode_detach) {
    pthread_handle_signal(channel.pthread_handle);
  }

  struct pthread_handle handle = pthread_handle_initializer;
  pthread_t threads[4];
  uint8_t active_threads = 0;
  pthread_attr_t attr;

  struct channel_cleanup cleanup = {.channel = &channel,
                                    .threads = threads,
                                    .attr = &attr,
                                    .num_threads = active_threads};
  pthread_cleanup_push(cancel_run_channel, &cleanup);

  // condition for waiting for any of the child threads to close
  channel.sinks[0].pthread_handle = &handle;
  channel.sinks[1].pthread_handle = &handle;

  // shrink stack size of threads for optimization
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, run_channel_sink_stacksize);

  int res;
  // Drain A
  res = pthread_create(threads + active_threads, &attr, run_channel_sink_drain,
                       channel.sinks + 0);
  if (res != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create channel sink A drain thread\n");
    pthread_exit((void *)1);
  }
  active_threads++;

  // FILL A
  res = pthread_create(threads + active_threads, &attr, run_channel_sink_fill,
                       channel.sinks + 0);
  if (res != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create channel sink A fill thread\n");
    pthread_exit((void *)1);
  }
  active_threads++;

  // DRAIN B
  res = pthread_create(threads + active_threads, &attr, run_channel_sink_drain,
                       channel.sinks + 1);
  if (res != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create channel sink B drain thread\n");
    pthread_exit((void *)1);
  }
  active_threads++;

  // FILL B
  res = pthread_create(threads + active_threads, &attr, run_channel_sink_fill,
                       channel.sinks + 1);
  if (res != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create channel sink B drain thread\n");
    pthread_exit((void *)1);
  }
  active_threads++;

  pthread_handle_wait(&handle); // wait for a child to exit
  pthread_cleanup_pop(true);
  pthread_exit(0);
}
