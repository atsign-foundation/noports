import select
import socket, logging, threading
class SocketConnector:
    _logger = logging.getLogger("sshrv | socket_connector")
    def __init__(self, server1_ip, server1_port, server2_ip, server2_port, reuse_port = False):
        # Create sockets for both servers
        self.socketA = socket.create_connection((server1_ip, server1_port))
        self.socketB = socket.create_connection((server2_ip, server2_port))
        
        self.server1_ip = server1_ip
        self.server1_port = server1_port
        self.server2_ip = server2_ip
        self.server2_port = server2_port
        
        if reuse_port:
            self.socketA.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socketA.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        
    def connect(self):
        sockets_to_monitor = [self.socketA, self.socketB]
        try:
            while True:
                readable, _, _ = select.select(sockets_to_monitor, [], [])
                
                for sock in readable:
                    data = sock.recv(1024)
                    if not data:
                        print("Connection closed.")
                        sockets_to_monitor.remove(sock)
                        sock.close()
                    else:
                        # Forward data to the other server
                        if sock is self.socketB:
                            self.socketA.send(data)
                        else:
                            self.socketB.send(data)
                            
        except Exception as e:
            raise(e)

        
            
    def close(self):
        self.socketA.close()
        self.socketB.close()
        
        
        