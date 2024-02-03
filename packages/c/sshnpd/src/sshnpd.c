#include "sshnpd_params.h"
#include <atclient/atkeysfile.h>
#include <atclient/atlogger.h>
#include <stdio.h>
#include <stdlib.h>

#define FILENAME_BUFFER_SIZE 500
#define LOGGER_TAG "sshnpd"

// Steps
// 4.  Load the atKeys
// 5.  Initialize the atClient
// 6.  If unhide, share username using put and notify
// 7.  Cache the manager public key
// 8.  Start heartbeat to the atServer
// 9.  Start monitor
// 10. Start the device refresh loop

int main(int argc, char **argv) {
  sshnpd_params *params = malloc(sizeof(sshnpd_params));

  // 1.  Load default values
  apply_default_values_to_params(params);

  // 2.  Parse the command line arguments
  if (parse_params(params, argc, (const char **)argv) != 0) {
    free(params);
    return 1;
  }

  // 3.  Configure the Logger
  if (params->verbose) {
    printf("Verbose mode enabled\n");
    atclient_atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_DEBUG);
  } else {
    atclient_atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);
  }

  // 4.  Load the atKeys
  atclient_atkeysfile keyfile;
  atclient_atkeysfile_init(&keyfile);

  int ret = 0;
  if (params->key_file != NULL) {
    atclient_atkeysfile_read(&keyfile, (const char *)params->key_file);
  } else {
    char homedir[200];
    // Unable to determine your home directory: please set $envVarName
    // environment variable atclient_logger_log_
    char filename[FILENAME_BUFFER_SIZE];
    snprintf(filename, FILENAME_BUFFER_SIZE, "%s/.atsign/keys/%s_key.atKeys",
             homedir, params->atsign);
    atclient_atkeysfile_read(&keyfile, filename);
  }

  free(params);
  return 0;
}
