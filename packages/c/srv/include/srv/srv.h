#ifndef SRV_H
#define SRV_H
#include "srv/params.h"
#include <atlogger/atlogger.h>
#include <mbedtls/aes.h>

// LOGGING
#define ERROR ATLOGGER_LOGGING_LEVEL_ERROR
#define WARN ATLOGGER_LOGGING_LEVEL_WARN
#define INFO ATLOGGER_LOGGING_LEVEL_INFO
#define DEBUG ATLOGGER_LOGGING_LEVEL_DEBUG

// NETWORKING
#define MAX_PORT_LEN 6 // 5 digits + null terminator

// BUFFER SIZES
// NB: This is currently hard coded to support AES, but may need to be modified
// for other transformation algorithms
#define READ_BLOCKS 4
#define READ_LEN (AES_BLOCK_LEN * READ_BLOCKS)
#define BUFFER_LEN (READ_LEN + AES_BLOCK_LEN + 1)

// Disable local bind for now
#define ALLOW_BIND_LOCAL_PORT 0
#define ALLOW_ENCRYPT_TRAFFIC 1

// A macro which will print an error and exit if local bind is attempted, and
// disabled - local bind won't be available in the parser either
#if ALLOW_BIND_LOCAL_PORT
void no_op() {}
#define halt_if_cant_bind_local_port() no_op();
#else
#define halt_if_cant_bind_local_port()                                                                                 \
  atlogger_log("srv - bind", ERROR, "--local-bind-port is disabled\n");                                                \
  exit(1);
#endif

// GENERAL SRV definitions
#define SRV_COMPLETION_STRING "rv started successfully"

#define AES_256_KEY_BYTES 32 // 256 bits = 32 bytes
#define AES_256_KEY_BITS 256

#define AES_BLOCK_LEN 16 // 128 bits = 16 bytes
struct _chunked_transformer;

/**
 * @brief type definition for a chunk based transform function
 *
 * @param self a pointer to the structure storing the context accessed by this function
 * @param len the output length of the buffer
 * @param input the buffer to crypt
 * @param output the output buffer to crypt
 * @return int 0 on success, non-zero on error
 */
typedef int(chunk_transform_t)(const struct _chunked_transformer *self, size_t len, const unsigned char *input,
                               unsigned char *output);

/**
 * @brief structure for storing the state behind aesctr stream encyption / decryption
 */
typedef struct _aes_ctr_transformer_state {
  mbedtls_aes_context ctx;
  unsigned char nonce_counter[AES_BLOCK_LEN];
  unsigned char stream_block[AES_BLOCK_LEN];
  size_t nc_off;
} aes_ctr_transformer_state_t;

/**
 * @brief a structure for handling a chunk based tranformer
 *
 * Contains the function pointer for the transform function, and the state/context required by that function.
 */
typedef struct _chunked_transformer {
  // Different transform functions expect different parameters/state union types
  chunk_transform_t *transform;

  // Transformer state/context
  union {
    aes_ctr_transformer_state_t aes_ctr;
  };
} chunked_transformer_t;

typedef struct {
    const srv_params_t *params;
    const char *auth_string;
    chunked_transformer_t *encrypter;
    chunked_transformer_t *decrypter;
    bool is_srv_ready;
} socket_to_socket_params_t;

/**
 * @brief run srv with some parameters
 *
 * @param params a pointer to the parameters to run srv with
 * @return int 0 on success, non-zero on error
 */
int run_srv(srv_params_t *params);

/**
 * @brief run srv daemon side single with some parameters
 *
 * @param params a pointer to the parameters to run srv with
 * @return int 0 on success, non-zero on error
 */
int run_srv_daemon_side_single(srv_params_t *params);

/**
 * @brief run srv daemon side multi with some parameters
 *
 * @param params a pointer to the parameters to run srv with
 * @return int 0 on success, non-zero on error
 */
int run_srv_daemon_side_multi(srv_params_t *params);

/**
 * @brief Run a socket to socket connection
 *
 * @param params a pointer to the original program parameters
 * @param auth_string an authentication string to send to the server at startup
 * @param encrypter a pointer to the encryption transformer used to encrypt messages sent to the server
 * @param decrypter a pointer to the decryption transformer used to decrypt messages from the server
 * @return int 0 on success, non-zero on error
 *
 * Note: the server in this context is the far side defined by params->host and params->port
 * Note: params->bind_local_port is expected to be 0
 */
int socket_to_socket(const srv_params_t *params, const char *auth_string, chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter, bool is_srv_ready);

/**
 * @brief Run a server to socket connection
 *
 * @param params a pointer to the original program parameters
 * @param auth_string an authentication string to send to the server at startup
 * @param encrypter a pointer to the encryption transformer used to encrypt messages sent to the server
 * @param decrypter a pointer to the decryption transformer used to decrypt messages from the server
 * @return int 0 on success, non-zero on error
 *
 * Note: the server in this context is the far side defined by params->host and params->port
 * Note: params->bind_local_port is expected to be 1
 */
int server_to_socket(const srv_params_t *params, const char *auth_string, chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter);

/**
 * @brief encrypt a chunk of a stream using aesctr
 *
 * @param self a pointer to the structure storing the context accessed by this function
 * @param len the output length of the buffer
 * @param input the buffer to crypt
 * @param output the output buffer to crypt
 * @return int 0 on success, non-zero on error
 */
int aes_ctr_crypt_stream(const chunked_transformer_t *self, size_t len, const unsigned char *input,
                         unsigned char *output);

int create_encrypter_and_decrypter(const char *session_aes_key_string, const char *session_aes_iv_string,
                                   chunked_transformer_t *encrypter, chunked_transformer_t *decrypter);
#endif
