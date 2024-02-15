#include "sshnpd/sshnpd.h"
#include <atclient/atclient.h>
#include <atclient/atkeys.h>
#include <atclient/atkeysfile.h>
#include <atlogger/atlogger.h>
#include <sshnpd/environment.h>
#include <sshnpd/params.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FILENAME_BUFFER_SIZE 500
#define LOGGER_TAG "sshnpd"
int main(int argc, char **argv) {
  SshnpdParams params;

  // 1.  Load default values
  apply_default_values_to_params(&params);

  // 2.  Parse the command line arguments
  if (parse_params(&params, argc, (const char **)argv) != 0) {
    return 1;
  }

  // 3.  Configure the Logger
  if (params.verbose) {
    printf("Verbose mode enabled\n");
    atclient_atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_DEBUG);
  } else {
    atclient_atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);
  }

  // 4. Validate the environment
  const char *homedir = getenv(HOMEVAR);
  if (homedir == NULL) {
    atclient_atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                          "Unable to determine your home directory: please "
                          "set %s environment variable\n",
                          HOMEVAR);
    return 1;
  }

  // TODO: move this to where it is used later
  const char *username = getenv(USERVAR);
  if (params.unhide && username == NULL) {
    atclient_atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                          "Unable to determine your username: please "
                          "set %s environment variable\n",
                          USERVAR);
    return 1;
  }

  // 5.  Load the atKeys
  atclient_atkeysfile atkeysfile;
  atclient_atkeysfile_init(&atkeysfile);

  // 5.1 Read the atKeys file
  int ret = 0;
  if (params.key_file != NULL) {
    ret = atclient_atkeysfile_read(&atkeysfile, (const char *)params.key_file);
  } else {
    char filename[FILENAME_BUFFER_SIZE];
    snprintf(filename, FILENAME_BUFFER_SIZE, "%s/.atsign/keys/%s_key.atKeys", homedir, params.atsign);
    ret = atclient_atkeysfile_read(&atkeysfile, filename);
  }

  if (ret != 0) {
    atclient_atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unable to read the key file\n");
    atclient_atkeysfile_free(&atkeysfile);
    return 1;
  }

  // 5.2 Read the atKeysFile into the atKeys struct
  atclient_atkeys atkeys;
  atclient_atkeys_init(&atkeys);

  ret = atclient_atkeys_populate_from_atkeysfile(&atkeys, atkeysfile);
  if (ret != 0) {
    atclient_atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unable to parse the key file\n");
    atclient_atkeysfile_free(&atkeysfile);
    atclient_atkeys_free(&atkeys);
    return 1;
  }
  atclient_atkeysfile_free(&atkeysfile);

  // 6. Initialize the atclient
  atclient atclient;
  atclient_init(&atclient);

  if (atclient_start_root_connection(&atclient, params.root_domain, ROOT_PORT) != 0) {
    atclient_atkeys_free(&atkeys);
    atclient_free(&atclient);
    return 1;
  }

  if (atclient_pkam_authenticate(&atclient, atkeys, params.atsign, strlen(params.atsign))) {
    atclient_atkeys_free(&atkeys);
    atclient_free(&atclient);
    return 1;
  }

  // TODO : can we free atkeys now?

  // 8.  Cache the manager public key
  // 8.1 build the atkey for the manager public key
  switch (params.manager_type) {
  case SingleManager:
    atclient_atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Single manager: %s\n", params.manager);
    break;
  case ManagerList:
    atclient_atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Manager List: %lu,", params.manager_list_len);
    for (int i = 0; i < params.manager_list_len; i++) {
      printf("%s,", params.manager_list[i]);
    }
    printf("\n");
    break;
  }

  // 9.  Start heartbeat to the atServer
  // 10. Start monitor
  // 11. Start the device refresh loop

  return 0;
}
