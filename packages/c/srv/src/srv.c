#include <MbedTLS/net_sockets.h>
#include <atchops/base64.h>
#include <netdb.h>
#include <srv/params.h>
#include <srv/srv.h>
#include <srv/stream.h>
#include <string.h>

#define MAX_PORT_DIGIT_COUNT 5
#define SERVER_BACKLOG 10

int run_srv(srv_params_t *params) {
  aes_transformer_t *encrypter = NULL;
  aes_transformer_t *decrypter = NULL;

  if (params->session_aes_key_string != NULL &&
      params->session_aes_iv_string != NULL) {
    encrypter = malloc(sizeof(aes_transformer_t));
    encrypter->key = params->session_aes_key_string;
    encrypter->iv = params->session_aes_iv_string;
    encrypter->transform = aes_encrypt_stream;

    decrypter = malloc(sizeof(aes_transformer_t));
    decrypter->key = params->session_aes_key_string;
    decrypter->iv = params->session_aes_iv_string;
    encrypter->transform = aes_decrypt_stream;
  };

  int res;
  if (params->bind_local_port == 0) {
    res =
        socket_to_socket(params, params->rvd_auth_string, encrypter, decrypter);
  } else {
    res =
        server_to_socket(params, params->rvd_auth_string, encrypter, decrypter);
  }

  if (encrypter != NULL) {
    free(encrypter);
  }
  if (decrypter != NULL) {
    free(decrypter);
  }
  return res;
}

int socket_to_socket(const srv_params_t *params, const char *auth_string,
                     aes_transformer_t *encrypter,
                     aes_transformer_t *decrypter) {
  // Get the socket for sideA
  side_t sideA = {1, 0, NULL, encrypter};
  int res = init_socket_for_side(NULL, params->local_port, &sideA);
  if (res != 0) {
    return res;
  }

  // Get the socket for sideB
  side_t sideB = {0, 0, auth_string, decrypter};
  res = init_socket_for_side(params->host, params->port, &sideB);
  if (res != 0) {
    return res;
  }

  // Create a thread for sideA
  pthread_t thread_id;
  pthread_create(&thread_id, NULL, handle_single_connection, &sideA);

  // Handle sideB on the current thread
  handle_single_connection(&sideB);

  // Wait for the thread to finish
  pthread_join(thread_id, NULL);

  res = close(sideA.sock_fd);
  res = close(sideB.sock_fd);
  return 0;
}

int server_to_socket(const srv_params_t *params, const char *auth_string,
                     aes_transformer_t *encrypter,
                     aes_transformer_t *decrypter) {

  // Get the socket for sideA
  side_t sideA = {1, 1, NULL, encrypter};
  int res = init_socket_for_side(NULL, params->local_port, &sideA);
  if (res != 0) {
    return res;
  }

  // Get the socket for sideB
  side_t sideB = {0, 0, auth_string, decrypter};
  res = init_socket_for_side(params->host, params->port, &sideB);
  if (res != 0) {
    return res;
  }

  int server_fd = sideA.sock_fd;
  // Listen for connections
  res = listen(server_fd, SERVER_BACKLOG);
  if (res != 0) {
    return res;
  }

  sideA.mutex = (pthread_mutex_t *)malloc(sizeof(pthread_mutex_t));
  pthread_mutex_init(sideA.mutex, NULL);

  sideA.connected_fd_count = malloc(sizeof(int));
  sideA.connected_fd = malloc(sizeof(int *) * SERVER_BACKLOG);

  pthread_t thread_b_id;
  pthread_create(&thread_b_id, NULL, handle_single_connection, &sideB);

  // Accept a connection
  // This will block until a connection is made
  int sock;
  while ((sock = accept(sideA.sock_fd, NULL, NULL)) >= 0) {
    side_t childA;
    memcpy(&childA, &sideA, sizeof(side_t));

    pthread_mutex_lock(sideA.mutex);
    childA.sock_fd = sock;
    sideA.connected_fd[*sideA.connected_fd_count] = &childA.sock_fd;
    sideA.connected_fd_count++;
    pthread_mutex_unlock(sideA.mutex);

    pthread_t thread_id;
    pthread_create(&thread_id, NULL, handle_single_connection, &sideA);
  }

  pthread_join(thread_b_id, NULL);
  pthread_mutex_destroy(sideA.mutex);

  return 0;
}

void *handle_single_connection(void *side) {
  side_t *s = (side_t *)side;
  size_t buff_length;
  size_t net_length;

  if (s->auth_string != NULL) {
    // Send the auth_string
    buff_length = strlen(s->auth_string);
    net_length = send(s->sock_fd, s->auth_string, buff_length, 0);
    if (net_length != buff_length) {
      printf("Failed to send auth_string\n");
      pthread_exit(NULL);
    }
  }

  char buffer[1024];
  while ((net_length = recv(s->sock_fd, buffer, 1024, 0)) > 0) {
    char *transformed;
    if (s->transformer == NULL) {
      s->transformer->transform(s->transformer, buffer, net_length, transformed,
                                &buff_length);
    } else {
      transformed = buffer;
      buff_length = net_length;
    }

    if (s->is_server == 1) {
      pthread_mutex_lock(s->mutex);
      for (int i = 0; i < *s->connected_fd_count; i++) {
        net_length = send(*s->connected_fd[i], transformed, buff_length, 0);
        if (net_length != buff_length) {
          printf("Failed to send data\n");
          pthread_exit(NULL);
        }
      }
      pthread_mutex_unlock(s->mutex);
    } else {

      net_length = send(s->sock_fd, transformed, buff_length, 0);
      if (net_length != buff_length) {
        printf("Failed to send data\n");
        pthread_exit(NULL);
      }
    }
  }
  pthread_exit(NULL);
}

int init_socket_for_side(const char *host, const uint16_t port, side_t *side) {
  struct addrinfo hints, *addr;
  struct sockaddr_in *sock_info;

  // Clean memory in hints
  memset(&hints, 0, sizeof(hints));

  hints.ai_socktype = SOCK_STREAM; // TCP
  if (side->is_server == 1) {
    hints.ai_flags =
        AI_PASSIVE |   // Enable binding
        AI_ADDRCONFIG; // Use the address family of the first valid address
  }

  // Convert port to string
  char port_as_str[MAX_PORT_DIGIT_COUNT];
  snprintf(port_as_str, MAX_PORT_DIGIT_COUNT, "%d", port);

  // Get the address using getaddrinfo
  int res = getaddrinfo(host, port_as_str, &hints, &addr);
  if (res != 0) {
    printf("Failed to lookup address: %s\n", gai_strerror(res));
    freeaddrinfo(addr);
    return 1;
  }

  // Cast the address to sockaddr_in
  sock_info = (struct sockaddr_in *)addr->ai_addr;

  // Create the socket
  int sock_fd =
      socket(sock_info->sin_family, addr->ai_socktype, addr->ai_protocol);
  if (sock_fd < 0) {
    // -1 failed to create socket
    // errno contains error
    freeaddrinfo(addr);
    return sock_fd;
  }

  if (side->is_server == 1) {
    // Enable address reuse
    const int on = 1;
    setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));

    // Bind the socket
    res = bind(sock_fd, addr->ai_addr, addr->ai_addrlen);
  } else {
    // Make sure the port is in network order
    sock_info->sin_port = htons(port);

    // Connect to the server
    res = connect(sock_fd, addr->ai_addr, addr->ai_addrlen);
  }

  // Be careful here, we haven't checked for errors from bind/connect yet

  freeaddrinfo(addr);
  if (res != 0) {
    return res;
  }

  // Set the socket in the side
  side->sock_fd = sock_fd;

  return 0;
}
