#include "run_socket_to_socket.h"
#include <srv/params.h>
#include <srv/srv.h>
#include <stdio.h>

static int socket_to_socket(struct srv_params params);
static int socket_to_server(struct srv_params params);
static int server_to_socket(struct srv_params params);
static int server_to_server(struct srv_params params);

int run_srv(struct srv_params params) {
  (void)params;
  // TODO reenable me
  // if (params.local_io == srv_io_type_tcp_client && params.remote_io ==
  // srv_io_type_tcp_client) {
  //   return socket_to_socket(params);
  // } else if (params.local_io == srv_io_type_tcp_client) {
  //   return socket_to_server(params);
  // } else if (params.remote_io == srv_io_type_tcp_client) {
  //   return server_to_socket(params);
  // } else {
  //   return server_to_server(params);
  // }
  return 0;
}

static int socket_to_socket(struct srv_params params) {
  struct session session;
  switch (params.mode) {
  case srv_mode_single:
    return run_socket_to_socket(&params, &session);
  case srv_mode_stacking:
    printf("stacking mode is not supported for tcp_client to tcp_client\n");
    return 1;
  case srv_mode_control:
    return 1; // TODO
  }
}

static int socket_to_server(struct srv_params params) {
  (void)params;
  printf("tcp_client-tcp_bind mode is not supported\n");
  return 1;
}

static int server_to_socket(struct srv_params params) {
  struct session session;
  switch (params.mode) {
  case srv_mode_single:
  case srv_mode_stacking:
    return 1; // TODO
  case srv_mode_control:
    return 1; // TODO
  }
  return 0;
}

static int server_to_server(struct srv_params params) {
  (void)params;
  printf("tcp_bind-tcp_bind mode is coming soon!");
  return 1;
}
