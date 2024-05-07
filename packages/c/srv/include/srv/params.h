#ifndef PARAMS_H
#define PARAMS_H
#define SRV_VERSION "0.1.0"

#include <argparse/argparse.h>
#include <getopt.h>
#include <stdbool.h>

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

  char *rvd_auth_string;
  char *session_aes_key_string;
  char *session_aes_iv_string;

} srv_params_t;

/**
 * @brief Apply the default values to a params structure
 *
 * @param params a pointer to the parameters structure to apply the defaults to.
 */
void apply_default_values_to_params(srv_params_t *params);

/**
 * @brief Parse parameters into a params structure
 *
 * @param params a pointer ot the parameters structure
 * @param argc the count of arguments
 * @param argv the list of arguments
 */
int parse_params(srv_params_t *params, int argc, const char **argv);

#endif
