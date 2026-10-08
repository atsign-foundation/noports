#include "sshnpd/handler_commons.h"
#include <atchops/base64.h>
#include <atchops/constants.h>
#include <atchops/rsa.h>
#include <atchops/rsa_key.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "test_keys.h"

static const char *PAYLOAD = "{\"sessionId\":\"9e13521b-9ad0-4237-9104-5824e6e6c483\"}";

int rsa2048_signer_test();
int rsa1024_signer_test();

int main() {
  int ret = 0;

  if (rsa2048_signer_test()) {
    printf("RSA-2048 signer test failed\n");
    ret++;
  }
  if (rsa1024_signer_test()) {
    printf("RSA-1024 signer test failed\n");
    ret++;
  }

  printf("Tests failed: %d\n", ret);
  return ret;
}

int rsa2048_signer_test() {
  atchops_rsa_key_public_key public_key;
  atchops_rsa_key_private_key private_key;
  atchops_rsa_key_public_key_init(&public_key);
  atchops_rsa_key_private_key_init(&private_key);
  unsigned char signature[256];
  int ret = 1;

  if (atchops_rsa_key_populate_public_key(&public_key, TEST_PUBLIC_KEY_B64, strlen(TEST_PUBLIC_KEY_B64)) != 0 ||
      atchops_rsa_key_populate_private_key(&private_key, TEST_PRIVATE_KEY_B64, strlen(TEST_PRIVATE_KEY_B64)) != 0 ||
      atchops_rsa_sign(&private_key, ATCHOPS_MD_SHA256, (const unsigned char *)PAYLOAD, strlen(PAYLOAD), signature) !=
          0) {
    printf("could not sign with the RSA-2048 test key\n");
    goto exit;
  }
  if (verify_envelope_signature(&public_key, (const unsigned char *)PAYLOAD, signature, "sha256", "rsa2048") != 0) {
    printf("refused a signature by an RSA-2048 key\n");
    goto exit;
  }
  ret = 0;
exit:
  atchops_rsa_key_public_key_free(&public_key);
  atchops_rsa_key_private_key_free(&private_key);
  return ret;
}

// A throwaway RSA-1024 public key, and its holder's SHA-256 signature over
// PAYLOAD, made once with openssl; the private key was not kept.
static const char *RSA1024_PUBLIC_KEY_B64 =
    "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDqXIwTd8q13jtZSk2WgsxXkH5rNfymxRvYeMHh"
    "0oZQME1sgPBn/GQjIeZliOW4FR7PH4Gl8GjdtZwD1UkCJBd4pEWT6ZZD03Jsh8RXZBnJK/0pIqaz"
    "yCWs1IKhFYL3wyB/NL8PCzHUoVWaUepyXS34vR0q56g2EmN8wrGn5oy/GQIDAQAB";
static const char *RSA1024_SIGNATURE_B64 =
    "1auMEsCm0IK/D8S9ZW2KRZfc7aoKp/i/8gfKRN+NCwTBKgB+sv2Rb8+e1HrambTZQi+xdKw8Z9mz"
    "BJcBe1UJbPKykhjgXlW3BW7jKQ9HkMibzPuN0aCPUnkk9uAmKaBRj5+3zsDaEi2dHSy8SVrzRCOx"
    "OWaPaxJ8iITxQvSM8MU=";

// The RSA-1024 signature is valid, but it must still be refused, since the
// daemon takes envelope signatures only from 2048-bit keys.
int rsa1024_signer_test() {
  atchops_rsa_key_public_key public_key;
  atchops_rsa_key_public_key_init(&public_key);
  unsigned char signature[128];
  size_t signature_len = 0;
  int ret = 1;

  if (atchops_rsa_key_populate_public_key(&public_key, RSA1024_PUBLIC_KEY_B64, strlen(RSA1024_PUBLIC_KEY_B64)) != 0 ||
      atchops_base64_decode(RSA1024_SIGNATURE_B64, strlen(RSA1024_SIGNATURE_B64), signature, sizeof(signature),
                            &signature_len) != 0 ||
      signature_len != sizeof(signature)) {
    printf("could not load the RSA-1024 key and signature\n");
    goto exit;
  }
  if (atchops_rsa_verify(&public_key, ATCHOPS_MD_SHA256, (const unsigned char *)PAYLOAD, strlen(PAYLOAD), signature) !=
      0) {
    printf("the RSA-1024 signature does not verify, so the test proves nothing\n");
    goto exit;
  }
  if (verify_envelope_signature(&public_key, (const unsigned char *)PAYLOAD, signature, "sha256", "rsa2048") == 0) {
    printf("accepted a signature by an RSA-1024 key\n");
    goto exit;
  }
  ret = 0;
exit:
  atchops_rsa_key_public_key_free(&public_key);
  return ret;
}
