#ifndef SRV_SESSION_H
#define SRV_SESSION_H
#ifdef __cplusplus
extern "C" {
#endif
#include "channel.h"
#include "channel_list.h"

enum session_type {
  single_session_type,
  stacking_session_type,
  control_session_type
};

// session which is simply a single channel
struct single_session {
  struct channel channel;
};

// stacking session takes one or two bind ports which spawn/connect the
// appropriate far side
struct stacking_session {
  struct channel_io binds[2];
  struct channel channel;
};

// session which has a single io that controls the creation of application space
// channels
struct control_session {
  struct channel_io control_io;
  struct channel_list_node *channels_head;
};

struct session {
  enum session_type type;
  union {
    struct single_session single;
    struct stacking_session stacking;
    struct control_session control;
  };
};

int run_session(struct session *);

#ifdef __cplusplus
}
#endif
#endif
