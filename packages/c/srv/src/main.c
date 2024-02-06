#include <atchops/base64.h>
#include <netdb.h>
#include <srv/params.h>
#include <srv/srv.h>
#include <stdlib.h>

int main(int argc, char **argv) {
  srv_params_t *params = malloc(sizeof(srv_params_t));

  // 1.  Load default values
  apply_default_values_to_params(params);

  // 2.  Parse the command line arguments
  if (parse_params(params, argc, (const char **)argv) != 0) {
    free(params);
    return 1;
  }

  // 3. Call the run function
  int res = run_srv(params);

  free(params);
  return res;
}
