#include "sshnpd/background_jobs.h"
#include <atclient/atclient.h>
#include <atclient/atkeys.h>
#include <atclient/atkeysfile.h>
#include <atclient/connection.h>
#include <atlogger/atlogger.h>
#include <pthread.h>
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
    atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_DEBUG);
  } else {
    atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);
  }

  // 4. Validate the environment
  const char *homedir = getenv(HOMEVAR);
  if (homedir == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Unable to determine your home directory: please "
                 "set %s environment variable\n",
                 HOMEVAR);
    return 1;
  }

  // TODO: move this to where it is used later
  const char *username = getenv(USERVAR);
  if (params.unhide && username == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
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
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unable to read the key file\n");
    atclient_atkeysfile_free(&atkeysfile);
    return 1;
  }

  // 5.2 Read the atKeysFile into the atKeys struct
  atclient_atkeys atkeys;
  atclient_atkeys_init(&atkeys);

  ret = atclient_atkeys_populate_from_atkeysfile(&atkeys, atkeysfile);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unable to parse the key file\n");
    atclient_atkeysfile_free(&atkeysfile);
    atclient_atkeys_free(&atkeys);
    return 1;
  }
  atclient_atkeysfile_free(&atkeysfile);

  // 6. Initialize the root connection
  atclient_connection root_conn;
  atclient_connection_init(&root_conn);

  if (atclient_connection_connect(&root_conn, params.root_domain, ROOT_PORT) != 0) {
    atclient_atkeys_free(&atkeys);
    atclient_connection_free(&root_conn);
    return 1;
  }

  // 7. Initialize the atclient
  atclient atclient;
  atclient_init(&atclient);
  if (atclient_pkam_authenticate(&atclient, &root_conn, &atkeys, params.atsign)) {
    atclient_atkeys_free(&atkeys);
    atclient_connection_free(&root_conn);
    atclient_free(&atclient);
    return 1;
  }

  // 8. cache the manager public keys
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Manager List: %lu,", params.manager_list_len);
  for (int i = 0; i < params.manager_list_len; i++) {
    printf("%s,", params.manager_list[i]);

    char public_encryption_key[1024];
    // atclient_get_public_encryption_key(&atclient, params.manager_list[i], &public_encryption_key);
    // TODO: finish caching
  }
  printf("\n");

  // pipe to communicate with the threads we will create in 9 & 10
  int fds[2], res;
  int exit_res = 0;
  pipe(fds);

  // 9.  Start heartbeat to the atServer
  pthread_t heartbeat_tid;
  struct heartbeat_params heartbeat_params = {&atclient, fds[0], fds[1]};
  res = pthread_create(&heartbeat_tid, NULL, heartbeat, (void *)&heartbeat_params);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to start heartbeat thread\n");
    exit_res = res;
    goto exit;
  }

  // 10. Start the device refresh loop
  pthread_t refresh_tid;
  struct refresh_device_entry_params refresh_params = {&atclient, &params, fds[0], fds[1]};
  res = pthread_create(&heartbeat_tid, NULL, refresh_device_entry, (void *)&refresh_params);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to start refresh device entry thread\n");
    exit_res = res;
    goto cancel_heartbeat;
  }

  // 11. Start monitor
  // TODO: monitor

  sleep(10); // Temp sleep to ensure that heartbeat triggers once before the program exits
cancel_device_refresh:
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Cancelling device entry refresh thread\n");
  if (pthread_cancel(refresh_tid) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Failed to cancel device entry refresh thread\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Canceled device entry refresh thread\n");
  }
cancel_heartbeat:
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Cancelling heartbeat thread\n");
  if (pthread_cancel(heartbeat_tid) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Failed to cancel heartbeat thread\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Canceled heartbeat thread\n");
  }
exit:
  close(fds[0]);
  close(fds[1]);
  atclient_atkeys_free(&atkeys);
  atclient_free(&atclient);

  if (exit_res != 0) {
    return exit_res;
  }

  return 0;
}
