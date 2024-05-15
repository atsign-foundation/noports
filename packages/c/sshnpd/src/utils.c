#include <stddef.h>

int long_strlen(long n) {
  // could use log10 for this, but it's probably slower...
  size_t len = 0;

  if (n == 0) {
    return 1;
  }

  if (n < 0) {
    n *= -1;
    len++; // for the minus sign
  }

  for (long i = 1; i <= n; i *= 10) {
    len++;
  }

  return len;
}
