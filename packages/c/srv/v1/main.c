#include <srv/params.h>
#include <srv/srv.h>

int main(int argc, char **argv) {
  struct srv_params params;

  int ret = parse_srv_params(argc, argv, &params);
  if (ret != 0) {
    // logging already handled by parse_srv_params
    return ret;
  }

  return run_srv(params);
}
