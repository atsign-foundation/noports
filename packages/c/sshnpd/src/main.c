#include "params.h"
#include "version.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
  sshnpd_params *params = malloc(sizeof(sshnpd_params));
  apply_default_values_to_params(params);

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
  argc = argparse_parse(&argparse, argc, (const char **)argv);

  if (params->atsign == NULL) {
    printf("Invalid Argument(s): Option atsign is mandatory\n");
    free(params);
    return 1;
  } else if (params->manager == NULL) {
    printf("Invalid Argument(s) Option manager is mandatory\n");
    free(params);
    return 1;
  }

  if (!strcmp(ssh_algorithm_input, "ssh-rsa")) {
    params->ssh_algorithm = RSA;
  } else if (!strcmp(ssh_algorithm_input, "ssh-ed25519")) {
    params->ssh_algorithm = ED25519;
  } else {
    printf("FormatException: \"%s\" is not an allowed value for option "
           "\"ssh-algorithm\"\n",
           ssh_algorithm_input);
    free(params);
    return 1;
  }

  // print all params
  printf("\n\nParams:\n");
  printf("key_file: %s\n", params->key_file);
  printf("atsign: %s\n", params->atsign);
  printf("manager: %s\n", params->manager);
  printf("device: %s\n", params->device);
  printf("sshpublickey: %d\n", params->sshpublickey);
  printf("unhide: %d\n", params->unhide);
  printf("verbose: %d\n", params->verbose);
  printf("ssh_algorithm: %u\n", params->ssh_algorithm);
  printf("ephemeral_permission: %s\n", params->ephemeral_permission);
  printf("root_domain: %s\n", params->root_domain);
  printf("local_sshd_port: %d\n\n", params->local_sshd_port);

  free(params);
  return 0;
}
