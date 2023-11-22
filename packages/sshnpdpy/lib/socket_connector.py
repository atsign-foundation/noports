import socket, logging, threading, errno, select
from time import sleep
class SocketConnector:
    _logger = logging.getLogger("sshrv | socket_connector")
    def __init__(self, server1_ip, server1_port, server2_ip, server2_port, reuse_port = False, verbose = False):
        self._logger.setLevel(logging.INFO)
        self._logger.addHandler(logging.StreamHandler())
        if verbose:
            self._logger.setLevel(logging.DEBUG)
        
        # Create sockets for both servers
        self.socketA = socket.create_connection((server1_ip, server1_port))
        self.socketB = socket.create_connection((server2_ip, server2_port))
        self.socketA.setblocking(0)
        self.socketB.setblocking(0)
        self._logger.info("Sockets connected.")
        self._logger.debug(f"Created sockets for {server1_ip}:{server1_port} and {server2_ip}:{server2_port}")
        self.server1_ip = server1_ip
        self.server1_port = server1_port
        self.server2_ip = server2_ip
        self.server2_port = server2_port
        
        if reuse_port:
            self.socketA.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socketA.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        
        
    def connect(self):
        sockets_to_monitor = [self.socketA, self.socketB]
        timeout = 0
        try:
            while True:
                for sock in sockets_to_monitor:
                    try:
                        data = sock.recv(1024)
                        # if not data and timeout > 10:
                        #     print("Connection closed.")
                        #     sockets_to_monitor.remove(sock)
                        #     sock.close()
                        # elif not data: 
                        #     timeout += 1
                        #     sleep(1)
                        if data == b'' or not data:
                            continue
                        else:
                            # Forward data to the other server
                            if sock is self.socketA:
                                self._logger.debug("SEND A -> B : " + str(data))
                                self.socketB.send(data)
                            elif sock is self.socketB:
                                self._logger.debug("RECV B -> A : " + str(data))
                                self.socketA.send(data)
                            timeout = 0
                                
                    except socket.error as e:
                        if e.errno == errno.EWOULDBLOCK:
                            pass  # No data available, continue
                        else:
                            raise        
        except Exception as e:
            raise(e)
        
            
    def close(self):
        self.socketA.close()
        self.socketB.close()
        
        
        
        