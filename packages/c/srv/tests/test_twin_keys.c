#include <srv/srv.h>
#include <stdio.h>
#include <string.h>

// base64 encoded AES-256 keys (32 bytes) and ivs (16 bytes)
static const char *key_c2d = "1DPU9OP3CYvamnVBMwGgL7fm8yB1klAap0Uc5Z9R79g=";
static const char *iv_c2d = "MTIzNDU2Nzg5MEFCQ0RFRg==";
static const char *key_d2c = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=";
static const char *iv_d2c = "QUJDREVGMTIzNDU2Nzg5MA==";

static const char *message = "The quick brown fox jumps over the lazy dog";

static int transform(chunked_transformer_t *t, const unsigned char *input, unsigned char *output, size_t len) {
  return t->transform(t, len, input, output);
}

// Round trip a message through a single-key encrypter/decrypter pair
static int test_single_key_round_trip() {
  chunked_transformer_t encrypter, decrypter;
  size_t len = strlen(message);
  unsigned char ciphertext[64], plaintext[64];
  memset(ciphertext, 0, sizeof(ciphertext));
  memset(plaintext, 0, sizeof(plaintext));

  int res = create_encrypter_and_decrypter(key_c2d, iv_c2d, NULL, NULL, &encrypter, &decrypter);
  if (res != 0) {
    printf("single key: create_encrypter_and_decrypter failed: %d\n", res);
    return 1;
  }

  res = transform(&encrypter, (const unsigned char *)message, ciphertext, len);
  res += transform(&decrypter, ciphertext, plaintext, len);
  mbedtls_aes_free(&encrypter.aes_ctr.ctx);
  mbedtls_aes_free(&decrypter.aes_ctr.ctx);
  if (res != 0) {
    printf("single key: transform failed\n");
    return 1;
  }

  if (memcmp(ciphertext, message, len) == 0) {
    printf("single key: ciphertext matches plaintext - not encrypted!\n");
    return 1;
  }
  if (memcmp(plaintext, message, len) != 0) {
    printf("single key: round trip failed\n");
    return 1;
  }
  printf("single key: round trip OK\n");
  return 0;
}

// With twinned keys the daemon decrypts C2D traffic and encrypts D2C traffic,
// while the client does the opposite. Build both ends and check each direction.
static int test_twin_keys_both_directions() {
  chunked_transformer_t daemon_encrypter, daemon_decrypter;
  chunked_transformer_t client_encrypter, client_decrypter;
  size_t len = strlen(message);
  unsigned char ciphertext[64], plaintext[64];

  int res = create_encrypter_and_decrypter(key_c2d, iv_c2d, key_d2c, iv_d2c, &daemon_encrypter, &daemon_decrypter);
  if (res != 0) {
    printf("twin keys: create_encrypter_and_decrypter failed: %d\n", res);
    return 1;
  }

  // The client encrypts with the C2D key and decrypts with the D2C key
  res = create_transformer(key_c2d, iv_c2d, &client_encrypter);
  res += create_transformer(key_d2c, iv_d2c, &client_decrypter);
  if (res != 0) {
    printf("twin keys: create_transformer failed\n");
    mbedtls_aes_free(&daemon_encrypter.aes_ctr.ctx);
    mbedtls_aes_free(&daemon_decrypter.aes_ctr.ctx);
    return 1;
  }

  int failures = 0;

  // Client to daemon direction
  memset(ciphertext, 0, sizeof(ciphertext));
  memset(plaintext, 0, sizeof(plaintext));
  res = transform(&client_encrypter, (const unsigned char *)message, ciphertext, len);
  res += transform(&daemon_decrypter, ciphertext, plaintext, len);
  if (res != 0 || memcmp(plaintext, message, len) != 0) {
    printf("twin keys: C2D round trip failed\n");
    failures++;
  } else {
    printf("twin keys: C2D round trip OK\n");
  }

  // Daemon to client direction
  memset(ciphertext, 0, sizeof(ciphertext));
  memset(plaintext, 0, sizeof(plaintext));
  res = transform(&daemon_encrypter, (const unsigned char *)message, ciphertext, len);
  if (res != 0) {
    printf("twin keys: D2C encrypt failed\n");
    failures++;
  } else {
    // The D2C ciphertext must not be decryptable with the C2D key - this is
    // the property which distinguishes twinned keys from a single key
    chunked_transformer_t wrong_key_decrypter;
    if (create_transformer(key_c2d, iv_c2d, &wrong_key_decrypter) == 0) {
      unsigned char wrong[64];
      memset(wrong, 0, sizeof(wrong));
      transform(&wrong_key_decrypter, ciphertext, wrong, len);
      mbedtls_aes_free(&wrong_key_decrypter.aes_ctr.ctx);
      if (memcmp(wrong, message, len) == 0) {
        printf("twin keys: D2C traffic decrypted with the C2D key - keys are not twinned!\n");
        failures++;
      }
    }

    res = transform(&client_decrypter, ciphertext, plaintext, len);
    if (res != 0 || memcmp(plaintext, message, len) != 0) {
      printf("twin keys: D2C round trip failed\n");
      failures++;
    } else {
      printf("twin keys: D2C round trip OK\n");
    }
  }

  mbedtls_aes_free(&daemon_encrypter.aes_ctr.ctx);
  mbedtls_aes_free(&daemon_decrypter.aes_ctr.ctx);
  mbedtls_aes_free(&client_encrypter.aes_ctr.ctx);
  mbedtls_aes_free(&client_decrypter.aes_ctr.ctx);

  return failures;
}

int main() {
  int failures = 0;
  failures += test_single_key_round_trip();
  failures += test_twin_keys_both_directions();
  return failures;
}
