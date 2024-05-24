#include "srv/srv.h"
#include <atchops/base64.h>
#include <atclient/atclient.h>
#include <atlogger/atlogger.h>
#include <netdb.h>
#include <srv/params.h>
#include <srv/side.h>

#define TAG "srv - main"

int main(int argc, char **argv) {
  srv_params_t params;

  // 1.  Load default values
  apply_default_values_to_srv_params(&params);

  // 2.  Parse the command line arguments
  if (parse_srv_params(&params, argc, (const char **)argv, NULL) != 0) {
    return 1;
  }

  atlogger_set_logging_level(DEBUG);
  atlogger_log(TAG, INFO, "running srv\n");

  // 3. Call the run function
  int res = run_srv(&params);

  atlogger_log(TAG, INFO, "srv completing with code %d\n", res);
  return res;
}
