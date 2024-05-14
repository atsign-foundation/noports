#ifndef SSH_KEY_UTIL_H
#define PARAMS_H

enum supported_key_prefix {
  SKP_NONE,
  SKP_ESN, // ecdsa-sha2-nistp
  SKP_RS2, // rsa-sha2-
  SKP_RSA, // ssh-rsa
  SKP_ED9, // ssh-ed25519
};

#define SUPPORTED_KEY_PREFIX_LEN 5

int authorize_ssh_public_key(const char *homedir, const char *permissions, const char *key);
int deauthorize_ssh_public_key(const char *homedir, const char *key, const char *temp_file);

typedef struct {
  char *homedir;
  char *key;
} deauthorize_ssh_public_key_params;

#define DEAUTHORIZE_SSH_PUBLIC_KEY_DELAY 15
void deauthorize_ssh_public_key_job(void *deauthorize_ssh_public_key_params);
#endif
