#include "sshnpd/handler_commons.h"
#include <stdio.h>

int main() {
  int ret = 0;
  const char *held = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA";

  if (!public_signing_key_needs_publishing(NULL, held)) {
    printf("did not publish a signing key that isn't published\n");
    ret++;
  }
  if (public_signing_key_needs_publishing(held, held)) {
    printf("republished the signing key the daemon already published\n");
    ret++;
  }
  if (!public_signing_key_needs_publishing("MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEB", held)) {
    printf("kept a published signing key the daemon doesn't hold\n");
    ret++;
  }

  printf("Tests failed: %d\n", ret);
  return ret;
}
