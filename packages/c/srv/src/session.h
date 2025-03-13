#ifndef SRV_SESSION_H
#define SRV_SESSION_H
#ifdef __cplusplus
extern "C" {
#endif
#include "channel.h"

enum session_type {
  session_type_unset = 0,
  session_type_single,
  session_type_stacking,
  session_type_control,
};

// session which is simply a single channel
struct session_single {
  struct channel channel;
};

#define session_single_initializer                                             \
  (struct session_single) { .channel = channel_initializer }

// stacking session takes one or two bind ports which spawn/connect the
// appropriate far side
struct session_stacking {
  struct channel_io remote;
  struct channel_io local;
};

#define session_stacking_initializer                                           \
  (struct session_stacking) {                                                  \
    .remote = channel_io_initializer, .local = channel_io_initializer          \
  }

// session which has a single io that controls the creation of application space
// channels
struct session_control {
  struct channel_io remote;
  struct channel_io local;
};

#define session_control_initializer                                            \
  (struct session_control) {                                                   \
    .remote = channel_io_initializer, .local = channel_io_initializer          \
  }

struct session {
  enum session_type type;
  union {
    struct session_single single;
    struct session_stacking stacking;
    struct session_control control;
  };
};

struct session create_session(struct srv_params);

struct session create_session_single(struct srv_params);
struct session create_session_stacking(struct srv_params);
struct session create_session_control(struct srv_params);

int run_session(struct srv_params, struct session);

int run_session_single(struct srv_params, struct session);
int run_session_stacking(struct srv_params, struct session);
int run_session_control(struct srv_params, struct session);

#ifdef __cplusplus
}
#endif
#endif
