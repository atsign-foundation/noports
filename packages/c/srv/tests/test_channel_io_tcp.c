#include "channel_io.h"
#include "channel_io_tcp.h"
#include <atlogger/atlogger.h>

#define TEST_HOST "localhost"
#define TEST_PORT "46464"

#define TAG "test_channel_io_tcp"

int main() {
  // * bind a tcp server port

  struct channel_io_tcp_socket server;

  int ret = bind_channel_io_tcp(&server.interface, TEST_HOST, TEST_PORT);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to bind test port: %s:%s\n", TEST_HOST, TEST_PORT);
    return ret;
  }

  struct channel_io_tcp_info client;
  ret = create_channel_io_tcp_connect_context(&client.interface, TEST_HOST,
                                              TEST_PORT);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to create connect context for %s:%s\n", TEST_HOST,
                 TEST_PORT);
    return ret;
  }

  struct channel_io_tcp_socket client_conn, server_conn;

  ret = client.interface.connect(&client.interface, &client_conn.interface);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to connect to %s:%s\n", TEST_HOST, TEST_PORT);
    return ret;
  }

  // regression test - &X.interface == &X for channel_io wrapper structs
  if ((void *)&client.interface != &client) {
    atlogger_log(TAG " regression", ATLOGGER_LOGGING_LEVEL_ERROR,
                 "&client.interface != &client");
    return 1;
  }

  if ((void *)&server.interface != &server) {
    atlogger_log(TAG " regression", ATLOGGER_LOGGING_LEVEL_ERROR,
                 "&server.interface != &server");
    return 1;
  }

  // end of regression test

  ret = server.interface.accept(&server.interface, &server_conn.interface);
  if (ret != 0) {

    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to accept new connection\n");
    return ret;
  }

  ret = client_conn.interface.send(&client_conn.interface,
                                   (unsigned char *)"foo", 3);
  if (ret != 0) {

    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to send 'foo' to the server\n");
    return ret;
  }

  unsigned char foo_buffer[4];
  size_t foo_size;
  ret =
      server_conn.interface.recv(&server_conn.interface, foo_buffer, &foo_size);
  if (ret != 0) {
  }
  if (foo_size != 3) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Incorrect recv length on server, expected: 3; actual: '%zu'",
                 foo_size);
    return 1;
  }
  if (strncmp((char *)foo_buffer, "foo", 3) != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Incorrect recv on server, expected: 'foo'; actual: '%.*s'",
                 (int)foo_size, foo_buffer);
    return 1;
  }

  return 0;
}
