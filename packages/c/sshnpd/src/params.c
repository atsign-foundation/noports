#include <sshnpd/params.h>
#include <sshnpd/version.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define default_permitopen "localhost:22,localhost:3389"
void apply_default_values_to_sshnpd_params(sshnpd_params *params) {
  params->key_file = NULL;
  params->atsign = NULL;
  params->device = "default";
  params->sshpublickey = 0;
  params->hide = 0;
  params->verbose = 0;
  params->ssh_algorithm = ED25519;
  params->ephemeral_permission = "";
  params->root_domain = "root.atsign.org";
  params->local_sshd_port = 22;
}

int parse_sshnpd_params(sshnpd_params *params, int argc, const char **argv) {
  char *ssh_algorithm_input = "";
  char *manager = NULL;
  char *permitopen = NULL;
  ArgparseOption options[] = {
      OPT_HELP(),
      OPT_STRING('k', "key-file", &params->key_file, "Path to the key file"),
      OPT_STRING('a', "atsign", &params->atsign, "Atsign to use (mandatory)"),
      OPT_STRING('m', "manager", &manager, "Manager to use (mandatory)"),
      OPT_STRING('d', "device", &params->device, "Device to use"),
      OPT_BOOLEAN('s', "sshpublickey", &params->sshpublickey, "Generate ssh public key"),
      OPT_BOOLEAN('h', "hide", &params->hide, "Hide device from device entry (still responds to pings)"),
      OPT_BOOLEAN('v', "verbose", &params->verbose, "Verbose output"),
      OPT_STRING(0, "permit-open", &permitopen,
                 "Comma separated-list of host:port to which the daemon will permit a connection from an authorized "
                 "client. (defaults to \"localhost:22,localhost:3389\")"),
      OPT_STRING(0, "ssh-algorithm", &ssh_algorithm_input, "SSH algorithm to use"),
      OPT_STRING(0, "ephemeral-permission", &params->ephemeral_permission, "Ephemeral permission to use"),
      OPT_STRING(0, "root-domain", &params->root_domain, "Root domain to use"),
      OPT_INTEGER(0, "local-sshd-port", &params->local_sshd_port, "Local sshd port to use"),
      OPT_STRING(0, "storage-path", &params->storage_path, NULL),
      OPT_BOOLEAN('u', "un-hide", NULL, NULL),
      OPT_END(),
  };

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
  } else if (manager == NULL) {
    argparse_usage(&argparse);
    printf("Invalid Argument(s) Option manager is mandatory\n");
    return 1;
  }

  if (permitopen == NULL) {
    params->permitopen_str = malloc(sizeof(char) * (strlen(default_permitopen) + 1)); // FIXME: leaks
    if (params->permitopen_str == NULL) {
      printf("Failed to allocate memory for default permitopen string\n");
      return 1;
    }
    strcpy(params->permitopen_str, default_permitopen);
    permitopen = params->permitopen_str;
  }

  int manager_end = strlen(manager);
  int permitopen_end = strlen(permitopen);

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

  // Validation and type inference for manager list
  int sep_count = 0;
  // first counter the number of seperators
  for (int i = 0; i < manager_end - 1; i++) {
    if (manager[i] == ',') {
      sep_count++;
    }
  }

  // malloc pointers to each string, but don't malloc any more memory for individual char storage
  params->manager_list = malloc((sep_count + 1) * sizeof(char *)); // FIXME: leak
  if (params->manager_list == NULL) {
    printf("Failed to allocate memory for manager list\n");
    free(params->permitopen_str);
    return 1;
  }
  params->manager_list[0] = manager;
  int pos = 1; // Starts at 1 since we already added the first item to the list
  for (int i = 0; i < manager_end; i++) {
    if (manager[i] == ',') {
      // Set this comma to a null terminator
      manager[i] = '\0';
      if (manager[i + 1] == '\0') {
        // Trailing comma, so we over counted by one
        sep_count--;
        // The allocated memory has a double trailing null seperator, but that's fine
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

  // Repeat for permit-open
  sep_count = 0;
  for (int i = 0; i < permitopen_end - 1; i++) {
    if (permitopen[i] == ',') {
      sep_count++;
    }
  }

  // malloc pointers to each string, but don't malloc any more memory for individual char storage
  params->permitopen = malloc((sep_count + 1) * sizeof(char *)); // FIXME  leak
  if (params->permitopen == NULL) {
    printf("Failed to allocate memory for permitopen\n");
    free(params->manager_list);
    free(params->permitopen_str);
    return 1;
  }

  params->permitopen[0] = permitopen;
  pos = 1; // Starts at 1 since we already added the first item to the list
  for (int i = 0; i < permitopen_end; i++) {
    if (permitopen[i] == ',') {
      // Set this comma to a null terminator
      permitopen[i] = '\0';
      if (permitopen[i + 1] == '\0') {
        // Trailing comma, so we over counted by one
        sep_count--;
        // The allocated memory has a double trailing null seperator, but that's fine
        break;
      }
      // Keep track of the start of the next item
      params->permitopen[pos++] = permitopen + i + 1;
    }
  }
  params->permitopen_len = sep_count + 1;

  return 0;
}
