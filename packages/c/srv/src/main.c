#include "srv/srv.h"
#include <atchops/base64.h>
#include <atclient/atclient.h>
#include <atlogger/atlogger.h>
#include <fcntl.h>
#include <netdb.h>
#include <srv/params.h>
#include <srv/side.h>
#define TAG "srv - main"

int main(int argc, char **argv) {
  srv_params_t params;

  // 1.  Load default values
  apply_default_values_to_params(&params);

  // 2.  Parse the command line arguments
  if (parse_params(&params, argc, (const char **)argv) != 0) {
    return 1;
  }

  // TODO: remove this block later - used to debug srv when it's called by sshnpd

  // Create a timestamped file
  time_t t = time(NULL);
  struct tm *tm = localtime(&t);
  char filename[50];
  strftime(filename, 50, "srv-logs-%c.txt", tm);

  // Redirect stdout to a file
  int file_desc = open(filename, O_RDWR | O_CREAT | O_TRUNC, 0666);
  int copy_out = dup(fileno(stdout));
  dup2(file_desc, fileno(stdout));

  // Maximum verbosity with logger
  atclient_atlogger_set_logging_level(DEBUG);
  atclient_atlogger_log(TAG, INFO, "running srv\n");

  // TODO: Until here

  // 3. Call the run function
  int res = run_srv(&params);

  // TODO: remove
  fflush(stdout);

  atclient_atlogger_log(TAG, INFO, "srv completing with code %d\n", res);
  exit(res);
}
