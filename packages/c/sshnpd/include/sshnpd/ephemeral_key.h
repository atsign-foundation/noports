#ifndef SSHNPD_EPHEMERAL_KEY_H
#define SSHNPD_EPHEMERAL_KEY_H

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

// The ephemeral tunnel key flow (parity with the Dart daemon's
// startDirectSsh): for each ssh_request session the daemon generates a
// throwaway ssh keypair, authorizes the public key in authorized_keys with a
// restrictive entry (forced command + PermitOpen to the local sshd only),
// returns the private key to the client in the session response, and removes
// the authorized_keys entry shortly afterwards. The client uses it to bring
// up the initial tunnel ssh session, inside which --remote-sshd-port style
// forwards are made by sshd itself.

/**
 * @brief Generate a throwaway ssh keypair for one session by running
 * ssh-keygen (no shell involved; the session id is validated first).
 *
 * The key files are written under directory (created 0700 if needed), read
 * into memory and unlinked before returning.
 *
 * @param directory directory for the transient key files, e.g. $HOME/.sshnp
 * @param use_rsa true for rsa-4096, false for ed25519 (the default)
 * @param session_id the session id (uuid); also used in the file name
 * @param private_key_pem receives the malloc'd private key file contents
 * @param public_key receives the malloc'd public key line
 * @return int 0 on success
 */
int generate_ephemeral_ssh_keypair(const char *directory, bool use_rsa, const char *session_id,
                                   char **private_key_pem, char **public_key);

/**
 * @brief Append the ephemeral public key to authorized_keys, restricted the
 * same way the Dart daemon restricts it:
 * `command="echo \"ssh session complete\";sleep 20",PermitOpen="localhost:<port>"[,extra] <key> sshnp_ephemeral_<sid>`
 *
 * @param authkeys_file the daemon's open authorized_keys stream
 * @param authkeys_filename path of the authorized_keys file
 * @param public_key the public key line from generate_ephemeral_ssh_keypair
 * @param local_sshd_port the only host:port the tunnel session may open
 * @param session_id the session id (uuid)
 * @param extra_permissions extra authorized_keys options ('--ephemeral-permission'), may be NULL or ""
 * @return int 0 on success
 */
int authorize_ephemeral_public_key(FILE *authkeys_file, char *authkeys_filename, const char *public_key,
                                   uint16_t local_sshd_port, const char *session_id, const char *extra_permissions);

/**
 * @brief Remove this session's ephemeral key entry from authorized_keys.
 * @return int 0 on success (including when no entry was present)
 */
int deauthorize_ephemeral_public_key(FILE *authkeys_file, const char *authkeys_filename, const char *session_id);

/**
 * @brief Queue this session's ephemeral key for removal from
 * authorized_keys 15 seconds from now (long enough for the client to bring
 * up the tunnel session). Processed by ephemeral_key_sweep_deauthorizations.
 * If the queue is full the oldest queued key is removed immediately to make
 * room, hence the file arguments.
 */
void ephemeral_key_schedule_deauthorize(FILE *authkeys_file, const char *authkeys_filename, const char *session_id);

/**
 * @brief Remove any queued ephemeral keys whose grace period has passed.
 * Called from the daemon main loop; single threaded by design.
 */
void ephemeral_key_sweep_deauthorizations(FILE *authkeys_file, const char *authkeys_filename);

#endif
