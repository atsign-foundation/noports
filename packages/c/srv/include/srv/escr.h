#ifndef SRV_ESCR_H
#define SRV_ESCR_H

#include "srv/params.h"
#include <atchops/rsa_key.h>
#include <mbedtls/net_sockets.h>
#include <stdbool.h>

/**
 * @brief Build the response line for an ESCR (Encrypted Signed Challenge
 * Response) relay authentication challenge.
 *
 * The line has the form `<session_id>:<base64 payload>` (no trailing
 * newline). The construction matches RelayAuthenticatorESCR in the Dart
 * noports_core package byte for byte:
 * - sign the compact JSON `{"sid":...,"c":...,"side":...}` with
 *   RSASSA-PKCS1-v1_5 / SHA-256
 * - wrap payload, signature, algorithm names and the public signing key uri
 *   in an envelope, base64 encode it
 * - PKCS#7 pad and AES-256-CTR encrypt the base64 envelope with the
 *   session's relay auth key and the given iv
 * - wrap iv and ciphertext (both base64) in `{"iv":...,"e":...}` and base64
 *   encode that as the payload
 *
 * This function is deterministic for a given iv, which is what makes it unit
 * testable; callers must generate a fresh random 16 byte iv per socket.
 *
 * @param session_id the session id (uuid) this socket belongs to
 * @param challenge the challenge line received from the relay (no newline)
 * @param aes_key_base64 the base64 encoded 32 byte relay auth AES key
 * @param signing_key_uri the atProtocol uri of the public signing key
 * @param signing_key the RSA-2048 private signing key
 * @param is_side_a true for client sockets, false for daemon sockets
 * @param iv 16 random bytes, freshly generated per authentication
 * @param out_line receives a malloc'd NUL terminated response line
 * @return int 0 on success, non-zero on error
 */
int srv_escr_build_response(const char *session_id, const char *challenge, const char *aes_key_base64,
                            const char *signing_key_uri, const atchops_rsa_key_private_key *signing_key,
                            bool is_side_a, const unsigned char iv[16], char **out_line);

/**
 * @brief Run the ESCR authentication exchange on a freshly connected relay
 * socket: read the challenge line, send the response line, wait for "ok".
 *
 * Must complete before any session traffic is sent on the socket.
 *
 * @param socket the connected relay socket
 * @param params srv params carrying the escr_* fields
 * @return int 0 on success (relay replied "ok"), non-zero otherwise
 */
int srv_escr_authenticate(mbedtls_net_context *socket, const srv_params_t *params);

#endif
