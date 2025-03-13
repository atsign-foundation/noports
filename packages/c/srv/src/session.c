#include "session.h"
#include "atlogger/atlogger.h"

#define TAG "session"

struct session create_session(struct srv_params params) {
  switch (params.mode) {
  case srv_mode_single:
    return create_session_single(params);
  case srv_mode_stacking:
    return create_session_stacking(params);
  case srv_mode_control:
    return create_session_control(params);
  default:
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create session, unrecognized mode\n");
    return (struct session){.type = session_type_unset};
  }
}

int run_session(struct srv_params params, struct session session) {
  switch (session.type) {
  case session_type_single:
    return run_session_single(params, session);
  case session_type_stacking:
    return run_session_stacking(params, session);
  case session_type_control:
    return run_session_control(params, session);
  default:
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to run session, unrecognized mode\n");
    return -1;
  }
}
