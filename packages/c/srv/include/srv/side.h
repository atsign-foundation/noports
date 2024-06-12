#ifndef SIDE_H
#define SIDE_H
#include <mbedtls/net_sockets.h>
#include <netdb.h>
#include <srv/params.h>
#include <srv/srv.h>

/**
 * @brief input structure for the side_t type
 * This structure includes all of the predefined, or non-state values which are stored in the side_T type
 */
typedef struct _side_hints_t {
  const bool is_side_a;
  const bool is_server;
  const char *host;
  const uint16_t port;
  const chunked_transformer_t *transformer;
} side_hints_t;

/**
 * @brief Structure which represents one side of a connection.
 *
 * The first 5 parameters represent the predefined values that are set from the side_hints_t input.
 * is_side_a, is_server, host, port, and transformer.
 * The next 3 parameters are set dynamically during initialization.
 * The last 3 parameters are used to store server state.
 */
typedef struct _side_t {
  // From hints
  const bool is_side_a;
  const bool is_server;
  const char *host;
  const uint16_t port;
  const chunked_transformer_t *transformer;

  // During init
  mbedtls_net_context socket; // NB: free this with mbedtls_net_free
  struct _side_t *other;
  int main_pipe[2];

  // Server state (null when is_server is false)
  mbedtls_net_context **connections;
  int connection_count;
  int connection_capacity;
} side_t;

/**
 * @brief Initialize the state of a single side of the socket connection.
 *
 * @param hints a pointer to a structure containing the input parameters.
 * @param side a pointer to the side structure which will be initialized by this function.
 */
int srv_side_init(const side_hints_t *hints, side_t *side);

/**
 * @brief Link two sides of a socket connector together, and provide the main pipe to them.
 *
 * @param side_a one of the two sides being linked.
 * @param side_b one of the two sides being linked.
 * @param fds file descriptors for a pipe used to signal to the calling thread that a side has completed/exited.
 */
void srv_link_sides(side_t *side_a, side_t *side_b, int fds[2]);

/**
 * @brief Free the memory allocated for a single side of the socket connection.
 *
 * @param side a pointer to the side struture which will be freed by this function.
 */
void srv_side_free(side_t *side);

/**
 * @brief A pointer to the function which actually handles the side connection.
 *
 * @param side the structure for the side being handled.
 */
void *srv_side_handle(void *side);

#endif
