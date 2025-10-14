#include "atclient/notify.h"
#include "atclient/notify_params.h"
#include "atlogger/atlogger.h"
#include <atclient/atclient.h>
#include <string.h>

// proper error handling and memory management is not done in this program
// since it is only used as a development tool, it is not perfect code

int main(int argc, char **argv) {
  if (argc != 4) {
    printf("Usage: %s <from_atsign> <to_atsign> <device_name>\n", argv[0]);
    exit(1);
  }
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);

  char *from = argv[1];
  char *to = argv[2];
  char *device_name = argv[3];

  atclient_atkeys_file atkeys_file;
  atclient_atkeys_file_init(&atkeys_file);

  char *file_path = atkeys_file_get_default_path(from);
  if (file_path == NULL) {
    printf("A\n");
    return 1;
  }

  atclient_atkeys atkeys;
  atclient_atkeys_init(&atkeys);

  int ret = atclient_atkeys_populate_from_path(&atkeys, file_path);
  if (ret != 0) {
    printf("B\n");
    return ret;
  }

  atclient_atkey atkey;
  atclient_atkey_init(&atkey);

  size_t namespace_len = strlen(device_name) + 1 + 5 + 1;
  char namespace[namespace_len];
  snprintf(namespace, namespace_len, "%s.sshnp", device_name);
  atclient_atkey_set_shared_with(&atkey, to);
  atclient_atkey_set_key(&atkey, "graceful_shutdown");
  atclient_atkey_set_namespace_str(&atkey, namespace);
  atclient_atkey_set_shared_by(&atkey, from);

  atclient_notify_params params;
  atclient_notify_params_init(&params);

  atclient_notify_params_set_atkey(&params, &atkey);
  atclient_notify_params_set_operation(&params, ATCLIENT_NOTIFY_OPERATION_UPDATE);
  atclient_notify_params_set_value(&params, "foo"); // ignored, value doesn't matter
  atclient_notify_params_set_should_encrypt(&params, true);

  atclient atclient;
  atclient_init(&atclient);

  ret = atclient_pkam_authenticate(&atclient, from, &atkeys, NULL, NULL);
  if (ret != 0) {
    printf("C\n");
    return ret;
  }

  ret = atclient_notify(&atclient, &params, NULL);
  if (ret != 0) {
    printf("D\n");
    return ret;
  }

  printf("sent\n");
  return 0;
}
