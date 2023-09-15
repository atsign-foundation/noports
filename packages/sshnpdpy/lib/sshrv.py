import logging
import socket
import threading

from .socket_connector import SocketConnector


class SSHRV:
    def __init__(self, destination, port, local_port = 22):
        self.logger = logging.getLogger("sshrv")
        self.host = ""
        self.destination = destination
        self.local_ssh_port = local_port
        self.streaming_port = port

    
    def run(self):
        try:
            self.host = socket.gethostbyname(socket.gethostname())
            socket_connector = SocketConnector(self.host, self.local_ssh_port, self.destination, self.streaming_port)
            socket_connector.connect()
            return True
                
        except Exception as e:
            logging.error("SSHRV Error: " + str(e))