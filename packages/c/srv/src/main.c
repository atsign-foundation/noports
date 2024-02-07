#include "srv/srv.h"
#include <atchops/base64.h>
#include <atclient/atclient.h>
#include <atlogger/atlogger.h>
#include <netdb.h>
#include <srv/params.h>
#include <srv/side.h>
#include <stdlib.h>

#define TAG "srv - main"

int main(int argc, char **argv) {
  srv_params_t *params = malloc(sizeof(srv_params_t));

  // 1.  Load default values
  apply_default_values_to_params(params);

  // 2.  Parse the command line arguments
  if (parse_params(params, argc, (const char **)argv) != 0) {
    free(params);
    return 1;
  }

  atclient_atlogger_set_logging_level(INFO);
  atclient_atlogger_log(TAG, INFO, "running srv\n");

  // 3. Call the run function
  int res = run_srv(params);

  atclient_atlogger_log(TAG, INFO, "srv completed with code %d\n", res);
  free(params);
  return res;
}
