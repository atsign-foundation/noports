#include <srv/params.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void apply_default_values_to_srv_params(srv_params_t *params) {
  params->local_host = "localhost";
  params->local_port = 22;
  params->bind_local_port = 0;
  params->multi = 0;
  params->timeout = SRV_DEFAULT_TIMEOUT_SECONDS;
  params->rv_auth = 0;
  params->rv_e2ee = 0;
  params->rvd_auth_string = NULL;
  params->session_aes_key_c2d_string = NULL;
  params->session_aes_iv_c2d_string = NULL;
  params->session_aes_key_d2c_string = NULL;
  params->session_aes_iv_d2c_string = NULL;
  params->escr_auth = false;
  params->escr_is_side_a = false;
  params->escr_session_id = NULL;
  params->escr_aes_key_base64 = NULL;
  params->escr_signing_key_uri = NULL;
  params->escr_signing_key = NULL;
}

int parse_srv_params(srv_params_t *params, int argc, const char **argv, srv_env_t *environment) {

  char *relay_auth_mode = NULL;

// pragma GCC works for both gcc and clang
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
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
      OPT_STRING('a', "relay-auth-mode", &relay_auth_mode,
                 "Relay authentication mode: 'payload' (use --rv-auth instead) or 'escr'. escr reads "
                 "REMOTE_AUTH_ESCR_SESSION_ID, REMOTE_AUTH_ESCR_AES_KEY, REMOTE_AUTH_ESCR_PUB_KEY_URI, "
                 "REMOTE_AUTH_ESCR_SIGNING_PRIVKEY and REMOTE_AUTH_ESCR_IS_SIDE_A from the environment"),
      OPT_BOOLEAN(0, "rv-e2ee", &params->rv_e2ee,
                  "Whether this rv process will encrypt/decrypt all rvd socket "
                  "traffic"),
      OPT_BOOLEAN(0, "multi", &params->multi, "Whether to enable multiple connections or not"),
      OPT_INTEGER(0, "timeout", &params->timeout,
                  "How long to keep the socket connector open if there have been no connections"),
      OPT_END(),
  };
#pragma GCC diagnostic pop

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

  // ESCR relay auth (standalone binary path). The sshnpd in-process path
  // fills the escr_* fields directly and never comes through here.
  if (relay_auth_mode != NULL && strcmp(relay_auth_mode, "escr") == 0) {
    if (params->rv_auth == 1) {
      argparse_usage(&argparse);
      printf("--rv-auth and --relay-auth-mode escr are mutually exclusive\n");
      return 1;
    }
    params->escr_session_id = getenv("REMOTE_AUTH_ESCR_SESSION_ID");
    params->escr_aes_key_base64 = getenv("REMOTE_AUTH_ESCR_AES_KEY");
    params->escr_signing_key_uri = getenv("REMOTE_AUTH_ESCR_PUB_KEY_URI");
    char *escr_signing_privkey_base64 = getenv("REMOTE_AUTH_ESCR_SIGNING_PRIVKEY");
    char *escr_is_side_a = getenv("REMOTE_AUTH_ESCR_IS_SIDE_A");
    if (params->escr_session_id == NULL || params->escr_aes_key_base64 == NULL ||
        params->escr_signing_key_uri == NULL || escr_signing_privkey_base64 == NULL || escr_is_side_a == NULL) {
      argparse_usage(&argparse);
      printf("--relay-auth-mode escr requires REMOTE_AUTH_ESCR_SESSION_ID, REMOTE_AUTH_ESCR_AES_KEY, "
             "REMOTE_AUTH_ESCR_PUB_KEY_URI, REMOTE_AUTH_ESCR_SIGNING_PRIVKEY and REMOTE_AUTH_ESCR_IS_SIDE_A in the "
             "environment\n");
      return 1;
    }
    if (strcmp(escr_is_side_a, "true") == 0) {
      params->escr_is_side_a = true;
    } else if (strcmp(escr_is_side_a, "false") == 0) {
      params->escr_is_side_a = false;
    } else {
      printf("REMOTE_AUTH_ESCR_IS_SIDE_A must be 'true' or 'false'\n");
      return 1;
    }

    // Owned by this params struct for the lifetime of the process
    params->escr_signing_key = malloc(sizeof(atchops_rsa_key_private_key));
    if (params->escr_signing_key == NULL) {
      return 1;
    }
    atchops_rsa_key_private_key_init(params->escr_signing_key);
    if (atchops_rsa_key_populate_private_key(params->escr_signing_key, escr_signing_privkey_base64,
                                             strlen(escr_signing_privkey_base64)) != 0) {
      printf("Failed to parse REMOTE_AUTH_ESCR_SIGNING_PRIVKEY\n");
      atchops_rsa_key_private_key_free(params->escr_signing_key);
      free(params->escr_signing_key);
      params->escr_signing_key = NULL;
      return 1;
    }
    params->escr_auth = true;
  } else if (relay_auth_mode != NULL && strcmp(relay_auth_mode, "payload") != 0) {
    argparse_usage(&argparse);
    printf("Unknown --relay-auth-mode: %s\n", relay_auth_mode);
    return 1;
  }

  // Load the environment
  if (params->rv_auth == 1) {
    if (environment != NULL && environment->rvd_auth_string != NULL) {
      params->rvd_auth_string = environment->rvd_auth_string;
    } else {
      params->rvd_auth_string = getenv("RV_AUTH");
    }
    if (params->rvd_auth_string == NULL) {
      argparse_usage(&argparse);
      printf("--rv-auth enabled, but RV_AUTH is not in envionment\n");
      return 1;
    }
  }

  if (params->rv_e2ee == 1) {
    if (environment != NULL && environment->session_aes_key_c2d_string != NULL) {
      params->session_aes_key_c2d_string = environment->session_aes_key_c2d_string;
    } else {
      // RV_AES_C2D is preferred, RV_AES is the legacy name for the same key
      params->session_aes_key_c2d_string = getenv("RV_AES_C2D");
      if (params->session_aes_key_c2d_string == NULL) {
        params->session_aes_key_c2d_string = getenv("RV_AES");
      }
    }
    if (params->session_aes_key_c2d_string == NULL) {
      argparse_usage(&argparse);
      printf("--rv-e2ee enabled, but neither RV_AES_C2D nor RV_AES is in environment\n");
      return 1;
    }
    if (environment != NULL && environment->session_aes_iv_c2d_string != NULL) {
      params->session_aes_iv_c2d_string = environment->session_aes_iv_c2d_string;
    } else {
      // RV_IV_C2D is preferred, RV_IV is the legacy name for the same iv
      params->session_aes_iv_c2d_string = getenv("RV_IV_C2D");
      if (params->session_aes_iv_c2d_string == NULL) {
        params->session_aes_iv_c2d_string = getenv("RV_IV");
      }
    }
    if (params->session_aes_iv_c2d_string == NULL) {
      argparse_usage(&argparse);
      printf("--rv-e2ee enabled, but neither RV_IV_C2D nor RV_IV is in environment\n");
      return 1;
    }

    // Optional twinned key for the daemon to client direction. Both the key
    // and the iv must be supplied together, otherwise fall back to single-key.
    if (environment != NULL && environment->session_aes_key_d2c_string != NULL) {
      params->session_aes_key_d2c_string = environment->session_aes_key_d2c_string;
    } else {
      params->session_aes_key_d2c_string = getenv("RV_AES_D2C");
    }
    if (environment != NULL && environment->session_aes_iv_d2c_string != NULL) {
      params->session_aes_iv_d2c_string = environment->session_aes_iv_d2c_string;
    } else {
      params->session_aes_iv_d2c_string = getenv("RV_IV_D2C");
    }
    if ((params->session_aes_key_d2c_string == NULL) != (params->session_aes_iv_d2c_string == NULL)) {
      argparse_usage(&argparse);
      printf("RV_AES_D2C and RV_IV_D2C must be provided together\n");
      return 1;
    }
  }
  return 0;
}
