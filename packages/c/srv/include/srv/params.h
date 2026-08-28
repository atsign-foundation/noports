#ifndef SRV_PARAMS_H
#define SRV_PARAMS_H
#define SRV_VERSION "0.1.0"

// Matches DefaultArgs.srvTimeoutInSeconds in the Dart noports_core package
#define SRV_DEFAULT_TIMEOUT_SECONDS 30

// Matches the npt client's "never" timeout (-T 0 -> neverTimeoutDays = 365
// days in npt.dart); also keeps the double -> int conversion of the requested
// timeout in range
#define SRV_MAX_TIMEOUT_SECONDS (365 * 24 * 60 * 60)

#include <argparse/argparse.h>
#include <getopt.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct {
  char *rvd_auth_string;
  char *session_aes_key_c2d_string;
  char *session_aes_iv_c2d_string;
  char *session_aes_key_d2c_string;
  char *session_aes_iv_d2c_string;
} srv_env_t;

/**
 * @brief Free the memory allocated for a single side of the socket connection.
 *
 * @param side a pointer to the side struture which will be freed by this function.
 */
typedef struct {
  char *host;
  uint16_t port;
  uint16_t local_port;
  char *local_host;

  bool bind_local_port;
  bool rv_auth;
  bool rv_e2ee;
  bool multi;
  int timeout;

  char *rvd_auth_string;

  // Session encryption keys (base64). When twinned keys are in use, the C2D
  // (client to daemon) key decrypts inbound traffic and the D2C (daemon to
  // client) key encrypts outbound traffic. When the D2C strings are NULL the
  // C2D key is used in both directions (legacy single-key sessions).
  char *session_aes_key_c2d_string;
  char *session_aes_iv_c2d_string;
  char *session_aes_key_d2c_string;
  char *session_aes_iv_d2c_string;
} srv_params_t;

/**
 * @brief Apply the default values to a params structure
 *
 * @param params a pointer to the parameters structure to apply the defaults to.
 */
void apply_default_values_to_srv_params(srv_params_t *params);

/**
 * @brief Parse parameters into a params structure
 *
 * @param params a pointer ot the parameters structure
 * @param argc the count of arguments
 * @param argv the list of arguments
 */
int parse_srv_params(srv_params_t *params, int argc, const char **argv, srv_env_t *environment);

#endif
