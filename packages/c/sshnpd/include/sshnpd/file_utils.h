#ifndef SSH_KEY_UTIL_H
#define SSH_KEY_UTIL_H

#include <pthread.h>
#include <stdio.h>

enum supported_key_prefix {
  SKP_NONE,
  SKP_ESN, // ecdsa-sha2-nistp
  SKP_RS2, // rsa-sha2-
  SKP_RSA, // ssh-rsa
  SKP_ED9, // ssh-ed25519
};

#define SUPPORTED_KEY_PREFIX_LEN 5

typedef struct {
  FILE *authkeys_file;
  char *authkeys_filename;
  char *permissions; // not required for deauthorize
  char *key;
} authkeys_params;

int authorize_ssh_public_key(authkeys_params *params);
#endif
