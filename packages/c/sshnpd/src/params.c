#include <sshnpd/params.h>
#include <sshnpd/version.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void apply_default_values_to_params(sshnpd_params *params) {
  params->device = "default";
  params->sshpublickey = 0;
  params->unhide = 0;
  params->verbose = 0;
  params->ssh_algorithm = ED25519;
  params->ephemeral_permission = "";
  params->root_domain = "root.atsign.org";
  params->local_sshd_port = 22;
}

int parse_params(sshnpd_params *params, int argc, const char **argv) {
  char *ssh_algorithm_input;
  argparse_option options[] = {
      OPT_HELP(),
      OPT_STRING('k', "key-file", &params->key_file, "Path to the key file"),
      OPT_STRING('a', "atsign", &params->atsign, "Atsign to use (mandatory)"),
      OPT_STRING('m', "manager", &params->manager,
                 "Manager to use (mandatory)"),
      OPT_STRING('d', "device", &params->device, "Device to use"),
      OPT_BOOLEAN('s', "sshpublickey", &params->sshpublickey,
                  "Generate ssh public key"),
      OPT_BOOLEAN('u', "un-hide", &params->unhide, "Unhide device"),
      OPT_BOOLEAN('v', "verbose", &params->verbose, "Verbose output"),
      OPT_STRING(0, "ssh-algorithm", &ssh_algorithm_input,
                 "SSH algorithm to use"),
      OPT_STRING(0, "ephemeral-permission", &params->ephemeral_permission,
                 "Ephemeral permission to use"),
      OPT_STRING(0, "root-domain", &params->root_domain, "Root domain to use"),
      OPT_INTEGER(0, "local-sshd-port", &params->local_sshd_port,
                  "Local sshd port to use"),
      OPT_END(),
  };

  argparse argparse;
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
  } else if (params->manager == NULL) {
    argparse_usage(&argparse);
    printf("Invalid Argument(s) Option manager is mandatory\n");
    return 1;
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
      return 1;
    }
  }

  // TODO: improve atsign validation
  if (params->atsign[0] != '@') {
    printf("Invalid Argument(s): \"%s\" is not a valid atSign\n",
           params->atsign);
    return 1;
  }
  if (params->manager[0] != '@') {
    printf("Invalid Argument(s): \"%s\" is not a valid atSign\n",
           params->manager);
    return 1;
  }

  return 0;
}
