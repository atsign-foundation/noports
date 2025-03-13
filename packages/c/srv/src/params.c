#include "param_macros.h"
#include <srv/params.h>
#include <stdio.h>
#include <string.h>

static char *help_msg[] = {
    "Usage: srv [OPTIONS]",
    "\nGeneric Options:",
    "    --help                Show this help text.",
    "    --timeout             How long to keep the session open if there have "
    "been no connections made.",
    "                          (defaults to: 60)",
    "-m, --channel-mode        Channel mode [single, stacking, control]",
    "                          Single mode only allows a single TCP "
    "connection, rejecting all others",
    "                          Stacking mode allows many TCP connections, "
    "unmanaged. This mode should only be used",
    "                          when the remote side is the final application "
    "layer destination.",
    "                          Control mode allows many TCP connections, "
    "managed on both sides by a control socket.",
    "                          This mode should be used when another control "
    "mode srv is on the other remote side",
    "-v, --verbose             Verbose logging",
    "\nRemote Options:",
    "-h, --host (mandatory)    Remote host",
    "-p, --port (mandatory)    Remote port",
    "-i, --io-type             The remote connection type [tcp_bind, "
    "tcp_client]",
    "                          (defaults to: tcp_client)",
    "-t, --transformer         The remote transformer type [aes_ctr, none]",
    "                          (defaults to: aes_ctr)",
    "-a, --authentication      Authentication type [payload, none]",
    "                          (defaults to: payload)",
    "\nLocal Options:",
    "-H, --local-host          Local host",
    "                          (defaults to: localhost)",
    "-P, --local-port          Local port, use 0 for ephemeral port.",
    "                          (defaults to: 0)",
    "-I, --local-io-type       The local connection type [tcp_bind, "
    "tcp_client]",
    "                          (defaults to: tcp_client)",
    "\nEnvironment Variables:",
    "OUTBOUND_AES_KEY:         AES key in base64 format use to encrypt "
    "outbound to the remote",
    "OUTBOUND_AES_IV:          AES nonce in base64 format associated with "
    "OUTBOUND_AES_KEY",
    "INBOUND_AES_KEY:          AES key in base64 format use to decrypt inbound "
    "from remote",
    "INBOUND_AES_IV:           AES nonce in base64 format associated with "
    "INBOUND_AES_KEY",
    "REMOTE_AUTH_PAYLOAD:      Initial message sent to authenticate the remote "
    "connection",
    "\nLegacy Options:",
    "                          These options are preserved for backward "
    "compatibility",
    "                          prefer using the listed aliases instead.",
    "    --[no-]rv-auth        Alias for `-a payload`",
    "                          (`--no-rv-auth` is an alias for `-a none`)",
    "    --[no-]rv-e2ee        Alias for `-t aes_ctr`",
    "                          (`--no-rv-e2ee` is an alias for `-t none`)",
    "    --bind-local-port     Alias for `-I tcp_bind`",
    "    --multi               Alias for `-m control`",
};
#define help_length (sizeof(help_msg) / sizeof(help_msg[0]))

static void print_help() {
  for (size_t i = 0; i < help_length; i++) {
    printf("%s\n", help_msg[i]);
  }
}

int parse_srv_params(srv_params_t *params, int argc, const char **argv, srv_env_t *environment) {

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
    if (environment != NULL && environment->session_aes_key_string != NULL) {
      params->session_aes_key_string = environment->session_aes_key_string;
    } else {
      params->session_aes_key_string = getenv("RV_AES");
    }
    if (params->session_aes_key_string == NULL) {
      argparse_usage(&argparse);
      printf("--rv-e2ee enabled, but RV_AES is not in environment\n");
      return 1;
    }
    if (environment != NULL && environment->session_aes_iv_string != NULL) {
      params->session_aes_iv_string = environment->session_aes_iv_string;
    } else {
      params->session_aes_iv_string = getenv("RV_IV");
    }
    if (params->session_aes_iv_string == NULL) {
      argparse_usage(&argparse);
      printf("--rv-e2ee enabled, but RV_IV is not in environment\n");
      return 1;
    }
  }
int parse_srv_params(int argc, char **argv, struct srv_params *params) {
  *params = srv_params_initializer;
  for (int i = 1; i < argc; i++) {

    if (argv[i][0] != '-') {
      unrecognized(i);
    }

    switch (strlen(argv[i])) {
    case 2:
      switch (argv[i][1]) {
      case 'h':
        host(i);
        break;
      case 'p':
        port(i);
        break;
      case 'm':
        channel_mode(i);
        break;
      case 'v':
        params->verbose = 1;
        break;
      case 'i':
        io_type(i);
        break;
      case 't':
        transformer(i);
        break;
      case 'a':
        authentication(i);
        break;
      case 'H':
        local_host(i);
        break;
      case 'P':
        local_port(i);
        break;
      case 'I':
        local_io_type(i);
        break;
      default:
        unrecognized(i);
        break;
      }
      break;
    case 6:
      if (strncmp(argv[i], "--help", 6) == 0) {
        print_help();
        exit(0);
      } else if (strncmp(argv[i], "--host", 6) == 0) {
        host(i);
      } else if (strncmp(argv[i], "--port", 6) == 0) {
        port(i);
      } else {
        unrecognized(i);
      }
      break;
    case 7:
      if (strncmp(argv[i], "--multi", 7) == 0) {
        params->mode = srv_mode_control;
      } else {
        unrecognized(i);
      }
      break;
    case 9:
      if (strncmp(argv[i], "--io-type", 9) == 0) {
        io_type(i);
      } else if (strncmp(argv[i], "--timeout", 9) == 0) {
        timeout(i);
      } else if (strncmp(argv[i], "--rv-auth", 9) == 0) {
        params->remote_auth = srv_auth_type_payload;
      } else if (strncmp(argv[i], "--rv-e2ee", 9) == 0) {
        params->transformer = srv_transformer_aes_ctr;
      } else if (strncmp(argv[i], "--verbose", 9) == 0) {
        params->verbose = 1;
      } else {
        unrecognized(i);
      }

      break;
    case 12:
      if (strncmp(argv[i], "--local-host", 12) == 0) {
        host(i);
      } else if (strncmp(argv[i], "--local-port", 12) == 0) {
        port(i);
      } else if (strncmp(argv[i], "--no-rv-auth", 12) == 0) {
        params->remote_auth = srv_auth_type_none;
      } else if (strncmp(argv[i], "--no-rv-e2ee", 12) == 0) {
        params->transformer = srv_transformer_none;
      } else {
        unrecognized(i);
      }
      break;
    case 13:
      if (strncmp(argv[i], "--transformer", 13) == 0) {
        transformer(i);
      } else {
        unrecognized(i);
      }
      break;
    case 14:
      if (strncmp(argv[i], "--channel-mode", 13) == 0) {
        transformer(i);
      } else {
        unrecognized(i);
      }
      break;
    case 15:
      if (strncmp(argv[i], "--local-io-type", 15) == 0) {
        local_io_type(i);
      } else {
        unrecognized(i);
      }
      break;
    case 16:
      if (strncmp(argv[i], "--authentication", 16) == 0) {
        authentication(i);
      } else {
        unrecognized(i);
      }
      break;
    case 17:
      if (strncmp(argv[i], "--bind-local-port", 17) == 0) {
        params->local_io = srv_io_type_tcp_bind;
      } else {
        unrecognized(i);
      }
      break;
    default:
      unrecognized(i);
      break;
    } // end of switch (arglen)
  } // end of for
  return 0;
}
