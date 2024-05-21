#include <srv/params.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void apply_default_values_to_params(srv_params_t *params) {
  params->local_host = "localhost";
  params->local_port = 22;
  params->bind_local_port = 0;
  params->rv_auth = 0;
  params->rv_e2ee = 0;
}

int parse_params(srv_params_t *params, int argc, const char **argv) {
  struct argparse_option options[] = {
      OPT_BOOLEAN(0, "help", NULL, "show this help message and exit", argparse_help_cb, 0, OPT_NONEG),
      OPT_STRING('h', "host", &params->host, "rvd host"),
      OPT_INTEGER('p', "port", &params->port, "rvd port"),
      OPT_INTEGER(0, "local-port", &params->local_port,
                  "Local port (usually the sshd port) to bridge to; defaults to 22"),
      OPT_STRING(0, "local-host", &params->local_host, "Local host to bridge to; defaults to localhost"),
#if ALLOW_BIND_LOCAL_PORT
      OPT_BOOLEAN(0, "bind-local-port", &params->bind_local_port,
                  "Set this flag when we are bridging from a local sender"),
#endif
      OPT_BOOLEAN(0, "rv-auth", &params->rv_auth, "Whether this rv process will authenticate to rvd"),
      OPT_BOOLEAN(0, "rv-e2ee", &params->rv_e2ee,
                  "Whether this rv process will encrypt/decrypt all rvd socket "
                  "traffic"),
      OPT_END(),
  };

  struct argparse argparse;
  argparse_init(&argparse, options, NULL, 0);

  char description[24];
  snprintf(description, sizeof(description), "Version : %s\n", SRV_VERSION);
  argparse_describe(&argparse, description, "");
  argc = argparse_parse(&argparse, argc, argv);

  // Mandatory options
  if (params->host == NULL) {
    argparse_usage(&argparse);
    printf("Invalid Argument(s): Option host is mandatory\n");
    return 1;
  } else if (params->port == 0) {
    argparse_usage(&argparse);
    printf("Invalid Argument(s) Option port is mandatory\n");
    return 1;
  }

  // Load the environment
  if (params->rv_auth == 1) {
    params->rvd_auth_string = getenv("RV_AUTH");
    if (params->rvd_auth_string == NULL) {
      argparse_usage(&argparse);
      printf("--rv-auth enabled, but RV_AUTH is not in envionment\n");
      return 1;
    }
  }

  if (params->rv_e2ee == 1) {
    params->session_aes_key_string = getenv("RV_AES");
    if (params->session_aes_key_string == NULL) {
      argparse_usage(&argparse);
      printf("--rv-e2ee enabled, but RV_AES is not in environment\n");
      return 1;
    }

    params->session_aes_iv_string = getenv("RV_IV");
    if (params->session_aes_iv_string == NULL) {
      argparse_usage(&argparse);
      printf("--rv-e2ee enabled, but RV_IV is not in environment\n");
      return 1;
    }
  }
  return 0;
}
