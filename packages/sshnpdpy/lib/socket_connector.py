import socket, logging, threading
class SocketConnector:
    _logger = logging.getLogger("sshrv | socket_connector")
    def __init__(self, server1_ip, server1_port, server2_ip, server2_port):
        # Create sockets for both servers
        self.portA = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.portB = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        
        self.server1_ip = server1_ip
        self.server1_port = server1_port
        self.server2_ip = server2_ip
        self.server2_port = server2_port
        
    def connect(self):
        try:
            # Bind and listen on the first server socket
            self.portA.bind((self.server1_ip, self.server1_port))
            self.portA.listen(1)
            logging.debug(f"Server 1 listening on {self.server1_ip}:{self.server1_port}")
            
            # Connect to the second server
            self.portB.connect((self.server2_ip, self.server2_port))
            logging.debug(f"Connected to Server 2 at {self.server2_ip}:{self.server2_port}")
            
            # Accept a connection from the first server
            client_socket, client_address = self.portA.accept()
            logging.debug(f"Accepted connection from {client_address}")
            
            # Start two threads for bidirectional data transfer
            t1 = threading.Thread(target=self.transfer, args=(client_socket, self.portB))
            t2 = threading.Thread(target=self.transfer, args=(self.portB, client_socket))
            t1.start()
            t2.start()
        except Exception as e:
            raise(e)
            
    def transfer(self, source_socket, destination_socket):
        while True:
            data = source_socket.recv(1024)
            if not data:
                break
            if len(data) == 0:
                break
            destination_socket.send(data)
        self.close()
        
            
    def close(self):
        self.portA.close()
        self.portB.close()
        
        
        