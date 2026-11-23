#ifndef SSH_KEY_UTIL_H
#define SSH_KEY_UTIL_H

#include <stdbool.h>
#include <stdio.h>

// The authorized_keys option that begins every line sshnpd adds for a
// client's key, allowing logins only from the device's loopback address
#define SSHNPD_LOOPBACK_FROM_OPTION "from=\"127.0.0.1,::1\""

// The longest sshpublickey value sshnpd accepts, in bytes
#define SSHNPD_SSHPUBLICKEY_MAX_BYTES 8192

// The longest key comment kept on an authorized_keys line
#define SSHNPD_SSHPUBLICKEY_MAX_COMMENT_LEN 256

// The most characters of a refused value shown in a log line
#define SSHNPD_SSHPUBLICKEY_LOG_MAX_LEN 200

/**
 * @brief A client's ssh public key, checked and ready to be written to
 * authorized_keys as one line.
 */
typedef struct {
  char *line;            // ending in '\n'
  char *key_data;        // the key data, in base64
  bool comment_left_out; // the value's comment was not printable ASCII or was too long
} sshnpd_authorized_key;

/**
 * @brief Builds the authorized_keys line for value, a client's
 * "<type> <base64>[ <comment>]": SSHNPD_LOOPBACK_FROM_OPTION, then
 * ",<permissions>" when permissions is neither NULL nor empty, then the key.
 * Returns 0, or non-zero with *reason saying why value was refused; free key
 * with sshnpd_authorized_key_free.
 */
int sshnpd_authorized_key_build(const char *value, const char *permissions, sshnpd_authorized_key *key,
                                const char **reason);

/**
 * @brief Frees what sshnpd_authorized_key_build allocated in key.
 */
void sshnpd_authorized_key_free(sshnpd_authorized_key *key);

/**
 * @brief Whether permissions, a comma-separated list of authorized_keys
 * options, holds a "from" option, matching its name in any case and treating
 * commas inside double quotes as part of an option.
 */
bool sshnpd_permissions_hold_from(const char *permissions);

/**
 * @brief Writes value to out fit for one log line: each byte outside
 * printable ASCII shown escaped, as "\n", "\r", "\t" or "\xNN", and cut to at
 * most out_size - 1 characters without splitting an escape.
 */
void sshnpd_one_line_for_log(const char *value, char *out, size_t out_size);

/**
 * @brief The path of the authorized_keys file under home_dir, which this
 * neither opens nor creates; the caller frees it. NULL when out of memory.
 */
char *sshnpd_authorized_keys_filename(const char *home_dir);

/**
 * @brief Appends key's line to the authorized_keys file at filename, after a
 * '\n' when the file does not end in one, unless the key's key data is already
 * a whitespace-separated token on a line there. Creates a missing parent
 * directory with mode 0700 and a missing file with mode 0600. Sets *added to
 * whether it wrote the line; returns 0 on success.
 */
int authorize_ssh_public_key(const char *filename, const sshnpd_authorized_key *key, bool *added);

#endif
