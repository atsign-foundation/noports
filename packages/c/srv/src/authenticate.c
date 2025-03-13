#include "authenticate.h"
#include <stdlib.h>
#include <string.h>

int authenticate_remote(struct srv_params params, struct channel_io *io) {
  switch (params.remote_auth) {
  case srv_auth_type_none:
    return 0;
  case srv_auth_type_payload:
    if (io->type != channel_io_type_rw)
      return 1;

    char *payload = getenv("REMOTE_AUTH_PAYLOAD");
    if (payload == NULL)
      payload = getenv("RV_AUTH"); // legacy env var name
    if (payload == NULL)
      return 1;

    return io->send(io, (unsigned char *)payload, strlen(payload));
  }
}

int authenticate_local(struct srv_params params, struct channel_io *io) {
  (void)params;
  (void)io;
  // local auth not implemented yet
  return 0;
}
