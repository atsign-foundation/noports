import logging
import socket
import threading

from .socket_connector import SocketConnector


class SSHRV:
    def __init__(self, destination, port, local_port = 22, verbose = False):
        self.logger = logging.getLogger("sshrv")
        self.host = ""
        self.destination = destination
        self.local_ssh_port = local_port
        self.streaming_port = port
        self.socket_connector = None
        self.verbose = verbose

    
    def run(self):
        try:
            self.host = socket.gethostbyname(socket.gethostname())
            socket_connector = SocketConnector(self.host, self.local_ssh_port, self.destination, self.streaming_port, reuse_port=True, verbose=self.verbose)
            t1 = threading.Thread(target=socket_connector.connect)
            t1.start()
            self.socket_connector = t1
            return True
                
        except Exception as e:
            logging.error("SSHRV Error: " + str(e))
            
    def is_alive(self):
        return self.socket_connector.is_alive()
            
            