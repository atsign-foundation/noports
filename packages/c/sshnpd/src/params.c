#include <errno.h>
#include <sshnpd/authorization.h>
#include <sshnpd/params.h>
#include <sshnpd/permitopen.h>
#include <sshnpd/version.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define default_permitopen "localhost:22,localhost:3389"
void apply_default_values_to_sshnpd_params(sshnpd_params *params) {
  params->key_file = NULL;
  params->atsign = NULL;
  params->manager_list = NULL;
  params->manager_list_len = 0;
  params->normalized_manager_buf = NULL;
  params->policy = NULL;
  params->device = "default";
  params->sshpublickey = 0;
  params->hide = 0;
  params->verbose = 0;
  params->ssh_algorithm = ED25519;
  params->root_domain = "root.atsign.org";
  params->local_sshd_port = 22;
  params->storage_path = NULL;
}

int parse_sshnpd_params(sshnpd_params *params, int argc, const char **argv) {
  char *ssh_algorithm_input = "";
  char *manager = NULL;
  char *permitopen = NULL;
  char *ephemeral_permissions = NULL;

// pragma GCC works for both gcc and clang
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
  ArgparseOption options[] = {
      OPT_HELP(),
      OPT_STRING('k', "key-file", &params->key_file, "Path to the key file"),
      OPT_STRING('a', "atsign", &params->atsign, "Atsign to use (mandatory)"),
      OPT_STRING('m', "manager", &manager,
                 "atSign or list of atSigns (comma separated) that this device will accept requests from. At least one "
                 "of --manager and --policy-manager must be supplied."),
      OPT_STRING('p', "policy-manager", &params->policy,
                 "The atSign which this device will use to decide whether or not to accept requests from some client "
                 "atSign. At least one of --manager and --policy-manager must be supplied."),
      OPT_STRING('d', "device", &params->device, "Device to use"),
      OPT_BOOLEAN('s', "sshpublickey", &params->sshpublickey, "Generate ssh public key"),
      OPT_BOOLEAN('h', "hide", &params->hide, "Hide device from device entry (still responds to pings)"),
      OPT_BOOLEAN('v', "verbose", &params->verbose, "Verbose output"),
      OPT_STRING(0, "permit-open", &permitopen,
                 "Comma separated-list of host:port to which the daemon will permit a connection from an authorized "
                 "client. (defaults to \"localhost:22,localhost:3389\")"),
      OPT_STRING(0, "ssh-algorithm", &ssh_algorithm_input, "SSH algorithm to use"),
      OPT_STRING(0, "ephemeral-permission", &ephemeral_permissions, "(Kept for compatibility)"),
      OPT_STRING(0, "root-domain", &params->root_domain, "Root domain to use. If a host but no port is specified (e.g. 'root.atsign.org'), the default port 64 will be appended (defaults to \"root.atsign.org:64\")"),
      OPT_INTEGER(0, "local-sshd-port", &params->local_sshd_port, "Local sshd port to use"),
      OPT_STRING(0, "storage-path", &params->storage_path, NULL),

      // Doesn't do anything more, added in case old config would cause a parsing issue
      OPT_BOOLEAN('u', "un-hide", NULL, NULL),
      OPT_END(),
  };
#pragma GCC diagnostic pop

  Argparse argparse;
  argparse_init(&argparse, options, NULL, 0);

  char description[24];
  snprintf(description, sizeof(description), "Version : %s\n", SSHNPD_VERSION);
  argparse_describe(&argparse, description, "");
  argc = argparse_parse(&argparse, argc, argv);

  // Mandatory options
  if (params->atsign == NULL) {
    argparse_usage(&argparse);
    printf("Invalid Argument(s): Option atsign is mandatory\n");
    return 1;
  } else if (manager == NULL && params->policy == NULL) {
    argparse_usage(&argparse);
    printf("Invalid Argument(s) One of --manager or --policy-manager must be provided");
    return 1;
  }

  if (permitopen == NULL) {
    // With a policy manager and no explicit --permit-open, the policy
    // service's permitOpen list is the effective ACL, so the daemon's own
    // list defaults to allow-all rather than localhost only
    const char *effective_default = params->policy != NULL ? "*:*" : default_permitopen;
    params->permitopen_str = malloc(sizeof(char) * (strlen(effective_default) + 1));
    if (params->permitopen_str == NULL) {
      printf("Failed to allocate memory for default permitopen string\n");
      return 1;
    }
    strcpy(params->permitopen_str, effective_default);
    permitopen = params->permitopen_str;
  }
  if ((parse_permitopen(permitopen, &params->permitopen_hosts, &params->permitopen_ports, &params->permitopen_len,
                        false) != 0)) {
    printf("Failed to parse permit-open string\n");
    free(params->permitopen_str);
    return 1;
  }

  printf("permitting open:\n");
  for (size_t i = 0; i < params->permitopen_len; i++) {
    if (params->permitopen_ports[i] == 0) {
      printf("%s:*\n", params->permitopen_hosts[i]);
    } else {
      printf("%s:%d\n", params->permitopen_hosts[i], params->permitopen_ports[i]);
    }
  }

  if (strlen(ssh_algorithm_input) != 0) {
    // Parse ssh_algorithm_input to its enum value
    if (strcmp(ssh_algorithm_input, "ssh-rsa") == 0) {
      params->ssh_algorithm = RSA;
    } else if (strcmp(ssh_algorithm_input, "ssh-ed25519") == 0) {
      params->ssh_algorithm = ED25519;
    } else {
      argparse_usage(&argparse);
      printf("Invalid Argument(s): \"%s\" is not an allowed value for option "
             "\"ssh-algorithm\"\n",
             ssh_algorithm_input);
      free(params->permitopen_str);
      return 1;
    }
  }

  if (params->atsign[0] != '@') {
    printf("Invalid Argument(s): \"%s\" is not a valid atSign\n", params->atsign);
    free(params->permitopen_str);
    return 1;
  }

  int manager_end = 0;
  if (manager != NULL) {
    manager_end = strlen(manager);
  }

  // Validation and type inference for manager list
  int sep_count = 0;
  // first counter the number of seperators
  for (int i = 0; i < manager_end - 1; i++) {
    if (manager[i] == ',') {
      sep_count++;
    }
  }

  int pos; // position counter
  if (manager != NULL) {
    // malloc pointers to each string, but don't malloc any more memory for individual char storage
    params->manager_list = malloc((sep_count + 1) * sizeof(char *)); // FIXME: leak
    if (params->manager_list == NULL) {
      printf("Failed to allocate memory for manager list\n");
      free(params->permitopen_str);
      return 1;
    }
    params->manager_list[0] = manager;
    pos = 1; // Starts at 1 since we already added the first item to the list
    for (int i = 0; i < manager_end; i++) {
      if (manager[i] == ',') {
        // Set this comma to a null terminator
        manager[i] = '\0';
        if (manager[i + 1] == '\0') {
          break;
        }
        if (manager[i + 1] != '@') {
          printf("Invalid Argument(s): Expected a list of atSigns: \"%s\"\n", manager);
          free(params->manager_list);
          free(params->permitopen_str);
          return 1;
        }
        // Keep track of the start of the next item
        params->manager_list[pos++] = manager + i + 1;
      }
    }
    params->manager_list_len = sep_count + 1;

    char *norm_buf = malloc(params->manager_list_len * SSHNPD_ATSIGN_BUFFER_LEN);
    if (norm_buf == NULL) {
      printf("Failed to allocate memory for normalized manager list\n");
      free(params->manager_list);
      free(params->permitopen_str);
      return 1;
    }
    for (size_t i = 0; i < params->manager_list_len; i++) {
      char *slot = norm_buf + i * SSHNPD_ATSIGN_BUFFER_LEN;
      if (sshnpd_normalize_atsign(params->manager_list[i], slot, SSHNPD_ATSIGN_BUFFER_LEN) != 0) {
        printf("Invalid manager atSign: \"%s\"\n", params->manager_list[i]);
        free(norm_buf);
        free(params->manager_list);
        free(params->permitopen_str);
        return 1;
      }
      params->manager_list[i] = slot;
    }
    params->normalized_manager_buf = norm_buf;
  } else {
    params->manager_list_len = 0;
  }

  // Repeat for permit-open
  // Convert devicename to lower case
  for (char *c = params->device; c[0] != '\0'; c++) {
    if (*c >= 'A' && *c <= 'Z') {
      *c += ('a' - 'A');
    }
  }
  return 0;
}
