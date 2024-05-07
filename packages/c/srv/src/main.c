#include "srv/srv.h"
#include <atchops/base64.h>
#include <atclient/atclient.h>
#include <atlogger/atlogger.h>
#include <netdb.h>
#include <srv/params.h>
#include <srv/side.h>
#include <string.h>

#define TAG "srv - main"

int main(int argc, char **argv) {
  srv_params_t params;

  // 1.  Load default values
  apply_default_values_to_params(&params);

  // 2.  Parse the command line arguments
  if (parse_params(&params, argc, (const char **)argv) != 0) {
    return 1;
  }

  // Since this is a string, we have to allocate memory for the default value
  bool free_local_host = false;
  if (params.local_host == NULL) {
    free_local_host = true;
    params.local_host = malloc(10 * sizeof(char));
    strcpy(params.local_host, "localhost");
  }

  atlogger_set_logging_level(DEBUG);
  atlogger_log(TAG, INFO, "running srv\n");

  // 3. Call the run function
  int res = run_srv(&params);

  if (free_local_host) {
    free(params.local_host);
  }

  atlogger_log(TAG, INFO, "srv completing with code %d\n", res);
  return res;
}
