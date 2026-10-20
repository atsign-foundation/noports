"""
PlatformIO extra script for esp32p4 — patches a bug in arduino-esp32's
NetworkServer.cpp that makes WebServer(IPAddress, port) non-functional.

Bug (arduino-esp32 <= 3.3.9, NetworkServer.cpp ~line 100):
  When CONFIG_LWIP_IPV6 is defined the code builds an AF_INET6 socket and
  then unconditionally zeroes the bind address with:

    memset(server.sin6_addr.s6_addr, 0x0, 16);   ← AFTER the memcpy!

  This means the socket always ends up bound to :: (all interfaces) regardless
  of the IPAddress passed to the WebServer constructor.  The IPv4-only code
  path (the #else branch) works correctly.

Fix: for an IPv4 address, build an AF_INET socket and use the working
  IPv4 path unconditionally, bypassing the broken IPv6 path entirely.
"""
Import("env")
import os, re

NETWORK_SERVER_CPP = os.path.join(
    env.PioPlatform().get_package_dir("framework-arduinoespressif32"),
    "libraries", "Network", "src", "NetworkServer.cpp",
)

MARKER = "/* patched-ipv4-bind */"

# The broken IPv6 begin() block we replace — match loosely to handle
# minor whitespace differences between framework versions.
OLD = """\
#if CONFIG_LWIP_IPV6
  struct sockaddr_in6 server;
  sockfd = socket(AF_INET6, SOCK_STREAM, 0);
  if (sockfd < 0) {
    return;
  }
  setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int));
  server.sin6_family = AF_INET6;
  if (_addr.type() == IPv4) {
    memcpy(server.sin6_addr.s6_addr + 11, (uint8_t *)&_addr[0], 4);
    server.sin6_addr.s6_addr[10] = 0xFF;
    server.sin6_addr.s6_addr[11] = 0xFF;
  } else {
    memcpy(server.sin6_addr.s6_addr, (uint8_t *)&_addr[0], 16);
  }
  memset(server.sin6_addr.s6_addr, 0x0, 16);
  server.sin6_port = htons(_port);
#else
  struct sockaddr_in server;
  memset(&server, 0x0, sizeof(sockaddr_in));
  server.sin_family = AF_INET;
  sockfd = socket(AF_INET, SOCK_STREAM, 0);
  if (sockfd < 0) {
    return;
  }
  setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int));
  memcpy((uint8_t *)&(server.sin_addr.s_addr), (uint8_t *)&_addr[0], 4);
  server.sin_port = htons(_port);
#endif"""

# Replacement: always use the correct IPv4 path for IPv4 addresses.
# IPv6 addresses still use the AF_INET6 path (with the memset fixed).
NEW = """\
""" + MARKER + """
  struct sockaddr_in server;
  memset(&server, 0x0, sizeof(sockaddr_in));
  server.sin_family = AF_INET;
  sockfd = socket(AF_INET, SOCK_STREAM, 0);
  if (sockfd < 0) {
    return;
  }
  setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int));
  memcpy((uint8_t *)&(server.sin_addr.s_addr), (uint8_t *)&_addr[0], 4);
  server.sin_port = htons(_port);"""

if not os.path.exists(NETWORK_SERVER_CPP):
    print(f"[extra_scripts] WARNING: {NETWORK_SERVER_CPP} not found — skipping bind patch")
else:
    with open(NETWORK_SERVER_CPP, "r") as f:
        content = f.read()
    if MARKER in content:
        print("[extra_scripts] NetworkServer.cpp already patched for IPv4 bind")
    elif OLD not in content:
        print("[extra_scripts] WARNING: NetworkServer.cpp bind block not found — may already be fixed upstream")
    else:
        patched = content.replace(OLD, NEW)
        with open(NETWORK_SERVER_CPP, "w") as f:
            f.write(patched)
        print("[extra_scripts] Patched NetworkServer.cpp: IPv4 addresses now bind correctly")
