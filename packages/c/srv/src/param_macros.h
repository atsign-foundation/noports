#ifndef SRC_PARAM_MACROS_H
#define SRC_PARAM_MACROS_H
#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>

// This file contains macros to help with parsing params in params.c

#define unrecognized(i)                                                        \
  printf("Unrecognized argument: %s\n\n", argv[i]);                            \
  print_help();                                                                \
  return 1;

#define missing(param)                                                         \
  printf("Missing argument for %s\n\n", param);                                \
  return 1;

#define host(i)                                                                \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("host");                                                         \
    }                                                                          \
    params->host = argv[i];                                                    \
  }

#define port(i)                                                                \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("port");                                                         \
    }                                                                          \
    params->port = argv[i];                                                    \
  }

#define invalid_io_type(param)                                                 \
  printf("invalid io-type: %s, must be one of [tcp_bind, tcp_client]\n\n",     \
         param);                                                               \
  return 1;

#define io_type(i)                                                             \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("io-type");                                                      \
    }                                                                          \
    switch (strlen(argv[i])) {                                                 \
    case 8:                                                                    \
      if (strncmp(argv[i], "tcp_bind", 8) == 0) {                              \
        params->remote_io = srv_io_type_tcp_bind;                              \
      } else {                                                                 \
        invalid_io_type(argv[i]);                                              \
      }                                                                        \
      break;                                                                   \
    case 10:                                                                   \
      if (strncmp(argv[i], "tcp_client", 10) == 0) {                           \
        params->remote_io = srv_io_type_tcp_client;                            \
      } else {                                                                 \
        invalid_io_type(argv[i]);                                              \
      }                                                                        \
      break;                                                                   \
    default:                                                                   \
      invalid_io_type(argv[i]);                                                \
      break;                                                                   \
    }                                                                          \
  }

#define invalid_transformer(param)                                             \
  printf("invalid transformer: %s, must be one of [aes_ctr, none]\n\n",        \
         param);                                                               \
  return 1;

#define transformer(i)                                                         \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("transformer");                                                  \
    }                                                                          \
    switch (strlen(argv[i])) {                                                 \
    case 4:                                                                    \
      if (strncmp(argv[i], "none", 4) == 0) {                                  \
        params->transformer = srv_transformer_none;                            \
      } else {                                                                 \
        invalid_transformer(argv[i]);                                          \
      }                                                                        \
      break;                                                                   \
    case 7:                                                                    \
      if (strncmp(argv[i], "aes_ctr", 7) == 0) {                               \
        params->transformer = srv_transformer_aes_ctr;                         \
      } else {                                                                 \
        invalid_transformer(argv[i]);                                          \
      }                                                                        \
      break;                                                                   \
    default:                                                                   \
      invalid_transformer(argv[i]);                                            \
      break;                                                                   \
    }                                                                          \
  }

#define invalid_authentication(param)                                          \
  printf("invalid authentication: %s, must be one of [payload, none]\n\n",     \
         param);                                                               \
  return 1;

#define authentication(i)                                                      \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("authentication");                                               \
    }                                                                          \
    switch (strlen(argv[i])) {                                                 \
    case 4:                                                                    \
      if (strncmp(argv[i], "none", 4) == 0) {                                  \
        params->remote_auth = srv_auth_type_none;                              \
      } else {                                                                 \
        invalid_authentication(argv[i]);                                       \
      }                                                                        \
      break;                                                                   \
    case 7:                                                                    \
      if (strncmp(argv[i], "payload", 7) == 0) {                               \
        params->remote_auth = srv_auth_type_payload;                           \
      } else {                                                                 \
        invalid_authentication(argv[i]);                                       \
      }                                                                        \
      break;                                                                   \
    default:                                                                   \
      invalid_authentication(argv[i]);                                         \
      break;                                                                   \
    }                                                                          \
  }

#define local_host(i)                                                          \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("local-host");                                                   \
    }                                                                          \
    params->local_host = argv[i];                                              \
  }

#define local_port(i)                                                          \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("local-port");                                                   \
    }                                                                          \
    params->local_port = argv[i];                                              \
  }

#define invalid_local_io_type(param)                                           \
  printf(                                                                      \
      "invalid local-io-type: %s, must be one of [tcp_bind, tcp_client]\n\n",  \
      param);                                                                  \
  return 1;

#define local_io_type(i)                                                       \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("local-io-type");                                                \
    }                                                                          \
    switch (strlen(argv[i])) {                                                 \
    case 8:                                                                    \
      if (strncmp(argv[i], "tcp_bind", 8) == 0) {                              \
        params->local_io = srv_io_type_tcp_bind;                               \
      } else {                                                                 \
        invalid_local_io_type(argv[i]);                                        \
      }                                                                        \
      break;                                                                   \
    case 10:                                                                   \
      if (strncmp(argv[i], "tcp_client", 10) == 0) {                           \
        params->local_io = srv_io_type_tcp_client;                             \
      } else {                                                                 \
        invalid_local_io_type(argv[i]);                                        \
      }                                                                        \
      break;                                                                   \
    default:                                                                   \
      invalid_local_io_type(argv[i]);                                          \
      break;                                                                   \
    }                                                                          \
  }

#define timeout(i)                                                             \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("timeout");                                                      \
    }                                                                          \
    params->timeout = atoi(argv[i]);                                           \
    if (params->timeout < 0) {                                                 \
      printf(                                                                  \
          "invalid timeout: %s, must be a positive integer (in seconds)\n\n",  \
          argv[i]);                                                            \
    }                                                                          \
  }

#define invalid_channel_mode(param)                                            \
  printf("invalid channel-mode: %s, must be one of [single, stacking, "        \
         "control]\n\n",                                                       \
         param);                                                               \
  return 1;

#define channel_mode(i)                                                        \
  {                                                                            \
    if (argv[++i][0] == '-') {                                                 \
      missing("channel-mode");                                                 \
    }                                                                          \
    switch (strlen(argv[i])) {                                                 \
    case 6:                                                                    \
      if (strncmp(argv[i], "single", 6) == 0) {                                \
        params->mode = srv_mode_single;                                        \
      } else {                                                                 \
        invalid_channel_mode(argv[i]);                                         \
      }                                                                        \
      break;                                                                   \
    case 7:                                                                    \
      if (strncmp(argv[i], "control", 7) == 0) {                               \
        params->mode = srv_mode_control;                                       \
      } else {                                                                 \
        invalid_channel_mode(argv[i]);                                         \
      }                                                                        \
      break;                                                                   \
    case 8:                                                                    \
      if (strncmp(argv[i], "stacking", 8) == 0) {                              \
        params->mode = srv_mode_stacking;                                      \
      } else {                                                                 \
        invalid_channel_mode(argv[i]);                                         \
      }                                                                        \
      break;                                                                   \
    default:                                                                   \
      invalid_channel_mode(argv[i]);                                           \
      break;                                                                   \
    }                                                                          \
  }

#ifdef __cplusplus
}
#endif
#endif
