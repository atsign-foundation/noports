#!/bin/env python3
import os, threading, getpass, json, logging, subprocess, argparse, errno
from  cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
from io import StringIO
from queue import Empty, Queue
from time import sleep
from threading import Event
from paramiko import SSHClient, SSHException, WarningPolicy
from paramiko.ed25519key import Ed25519Key

from select import select
from socket import socket, gethostbyname, gethostname, create_connection, error

from at_client import AtClient
from at_client.common import AtSign
from at_client.util import EncryptionUtil, KeysUtil
from at_client.common.keys import AtKey, Metadata, SharedKey
from at_client.connections.notification.atevents import AtEvent, AtEventType


class SocketConnector:
    def __init__(self, server1_ip, server1_port, server2_ip, server2_port, logger):
        
        self._logger = logger
        # Create sockets for both servers
        self.socketA = create_connection((server1_ip, server1_port))
        self.socketB = create_connection((server2_ip, server2_port))
        self.socketA.setblocking(0)
        self.socketB.setblocking(0)
        self._logger.info("Sockets connected.")
        self._logger.debug(f"Created sockets for {server1_ip}:{server1_port} and {server2_ip}:{server2_port}")
        self.server1_ip = server1_ip
        self.server1_port = server1_port
        self.server2_ip = server2_ip
        self.server2_port = server2_port

    def connect(self):
        sockets_to_monitor = [self.socketA, self.socketB]
        timeout = 0
        try:
            while True:
                for sock in sockets_to_monitor:
                    try:
                        data = sock.recv(1024)
                        if not data and timeout > 100:
                            print("Connection closed.")
                            sockets_to_monitor.remove(sock)
                            sock.close()
                        elif not data: 
                            timeout += 1
                            sleep(0.1)
                        if data == b'':
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
                                
                    except error as e:
                        if e.errno == errno.EWOULDBLOCK:
                            pass  # No data available, continue
                        else:
                            raise        
        except Exception as e:
            raise(e)

    def close(self):
        self.socketA.close()
        self.socketB.close()


class SSHRV:
    def __init__(self, destination, port, local_port = 22, verbose = False):
        self.logger = logging.getLogger("sshrv | socket_connector")
        self.logger.propagate = False
        self.logger.addHandler(logging.StreamHandler())
        if verbose:
            self.logger.setLevel(logging.DEBUG)
        else:
            self.logger.setLevel(logging.INFO)
            
        self.host = ""
        self.destination = destination
        self.local_ssh_port = local_port
        self.streaming_port = port
        self.socket_connector = None
        self.verbose = verbose

    def run(self):
        try:
            self.host = gethostbyname(gethostname())
            socket_connector = SocketConnector(self.host, self.local_ssh_port, self.destination, self.streaming_port, logger=self.logger)
            t1 = threading.Thread(target=socket_connector.connect)
            t1.start()
            self.socket_connector = t1
            return True
                
        except Exception as e:
            logging.error("SSHRV Error: " + str(e))
            raise e
            
    def is_alive(self):
        return self.socket_connector.is_alive()


class SSHNPDClient:
    #Current opened threads
    threads = []

    def __init__(self, atsign, manager_atsign, device, username=None, verbose=False, expecting_ssh_keys = False):  
        #Threading Stuff
        self.closing = Event()
        self.closing.clear()
        
        #AtClient Stuff
        self.atsign = atsign
        self.manager_atsign = manager_atsign
        self.device = device
        self.username = username
        self.device_namespace = f".{device}.sshnp"
        self.at_client = AtClient(AtSign(atsign), queue=Queue(maxsize=20), verbose=verbose)
        
        #SSH Stuff
        self.ssh_client = None
        self.authenticated = False
        self.rv = None
        self.expecting_ssh_keys = expecting_ssh_keys
        
        #Logger
        self.logger = logging.getLogger("sshnpd")
        self.logger.setLevel((logging.DEBUG if verbose else logging.INFO))
        self.logger.addHandler(logging.StreamHandler())
        
        #Directory Stuff
        home_dir = ""
        if os.name == "posix":  # Unix-based systems (Linux, macOS)
            home_dir = os.path.expanduser("~")
        elif os.name == "nt":  # Windows
            home_dir = os.path.expanduser("~")
        else:
            raise NotImplementedError("Unsupported operating system")
        self.ssh_path = f"{home_dir}/.ssh"

    def start(self):
        if self.username:
            self._set_username()
        threading.Thread(target=self.at_client.start_monitor, args=(self.device_namespace,)).start()
        threading.Thread(target=self._handle_notifications, args=(self.at_client.queue,), daemon=True).start()
        event_thread = threading.Thread(target=self._handle_events, args=(self.at_client.queue,))
        event_thread.start()
        SSHNPDClient.threads.append(event_thread)

    def is_alive(self):
        if not self.authenticated:
            return True
        elif len(SSHNPDClient.threads) >= 2 and self.ssh_client.get_transport().is_active():
            return True
        elif self.rv.is_alive():
            return True
        else:
            return False

    def join(self):
        self.closing.set()
        if self.ssh_client:
            self.ssh_client.close()
        self.at_client.stop_monitor()
        for thread in SSHNPDClient.threads:
            thread.join()
        SSHNPDClient.threads.clear()

    def _set_username(self):
        username = getpass.getuser()
        username_key = SharedKey(
            "username", AtSign(self.atsign), AtSign(self.manager_atsign))
        self.at_client.put(username_key, username)
        self.username = username

    def _handle_notifications(self, queue: Queue):
        private_key = ""
        ssh_public_key_received = True if not self.expecting_ssh_keys else (False if "" else True) #sorry for making this so cursed
        ssh_notification_recieved = False
        
        while not self.closing.is_set():
            try:
                at_event = queue.get(block=False)
                event_type = at_event.event_type
                event_data = at_event.event_data
                
                if event_type == AtEventType.UPDATE_NOTIFICATION:
                    queue.put(at_event)
                    sleep(1)
                if event_type != AtEventType.DECRYPTED_UPDATE_NOTIFICATION:
                    continue
                
                key = event_data["key"].split(":")[1].split(".")[0]
                decrypted_value = str(event_data["decryptedValue"])
                
                if key == "privatekey":
                    self.logger.debug(
                        f'private key received from ${event_data["from"]} notification id : ${event_data["id"]}')
                    private_key = decrypted_value
                    continue

                if key == "sshpublickey":
                    self.logger.debug(f'ssh Public Key received from ${event_data["from"]} notification id : ${event_data["id"]}')
                    self._handle_ssh_public_key(decrypted_value)
                    continue
                #reverse ssh
                if key == "sshd":
                    self.logger.debug(
                        f'ssh callback requested from {event_data["from"]} notification id : {event_data["id"]}')
                    ssh_notification_recieved = True
                    callbackArgs = [
                        at_event,
                        private_key,
                        False
                    ] 
                    try:
                        threading.Thread(target=self.sshnp_callback, args=(callbackArgs)).start()
                    except Exception as e:
                        raise e
                #direct ssh
                if key == 'ssh_request':
                    self.logger.debug(
                        f'ssh callback requested from {event_data["from"]} notification id : {event_data["id"]}')
                    callbackArgs = [
                        at_event,
                        "",
                        True
                    ]
                    try:
                        threading.Thread(target=self.sshnp_callback, args=(callbackArgs)).start()
                    except Exception as e:
                        raise e
            except Empty:
                pass

    #Running in a thread
    def _handle_events(self, queue: Queue):  
        while not self.closing.is_set():
            try:
                at_event = queue.get(block=False)
                event_type = at_event.event_type
                # the Main thread needs to access the queue AFTER the handle thread has finished with it
                if event_type == AtEventType.DECRYPTED_UPDATE_NOTIFICATION:
                    queue.put(at_event)
                    sleep(1)
                else:
                    if event_type == AtEventType.UPDATE_NOTIFICATION:
                        self.at_client.secondary_connection.execute_command(
                            "notify:remove:" + at_event.event_data["id"]
                        )
                    self.at_client.handle_event(queue, at_event)
            except Empty:
                pass  
            
    def _direct_ssh(self, hostname, port, sessionId):
        sshrv = SSHRV(hostname, port)
        data = ""
        try:
            sshrv.run()
            self.rv = sshrv
            self.logger.info("sshrv started @ "  + hostname + " on port " + str(port))
            (public_key, private_key)= self._generate_ssh_keys()
            private_key = private_key.replace("\n", "\\n")
            self._handle_ssh_public_key(public_key)
            data = f'{{"status":"connected","sessionId":"{sessionId}","ephemeralPrivateKey":"{private_key}"}}'
        except Exception as e:
            data = f'{{"status":""Remote SSH Client failure : {e}","sessionId":"{sessionId}"}}'
            
        signature =  EncryptionUtil.sign_sha256_rsa(data, self.at_client.keys[KeysUtil.encryption_private_key_name])
        envelope = f'{{"payload":{data},"signature":"{signature}","hashingAlgo":"sha256","signingAlgo":"rsa2048"}}'
        return envelope 

    def sshnp_callback(
        self,   
        event: AtEvent,
        private_key="",
        direct=False,
    ):
        uuid = event.event_data["id"]
        if direct:
            ssh_list = json.loads(event.event_data["decryptedValue"])['payload']
        else:
            ssh_list = event.event_data["decryptedValue"].split(" ")
        iv_nonce = EncryptionUtil.generate_iv_nonce()
        metadata = Metadata(
            ttl=10000,
            ttr=-1,
            iv_nonce=iv_nonce,
        )
        at_key = AtKey(f"{uuid}.{self.device}", self.atsign)
        at_key.shared_with = AtSign(self.manager_atsign)
        at_key.metadata = metadata
        at_key.namespace = self.device_namespace
        if len(ssh_list) == 5 or direct:
            uuid =  ssh_list['sessionId'] if direct else ssh_list[4]
            at_key = AtKey(f"{uuid}", self.atsign)
            at_key.shared_with = AtSign(self.manager_atsign)
            at_key.metadata = metadata
            at_key.namespace =self.device_namespace
        ssh_response = None
        
        if direct:
            ssh_response = self._direct_ssh(ssh_list['host'], ssh_list['port'], ssh_list['sessionId'])
        else:
            ssh_response = self._reverse_ssh_client(ssh_list, private_key)
        
        if ssh_response:
            notify_response = self.at_client.notify(at_key, ssh_response, session_id=uuid)
            self.logger.info("sent ssh notification to " + at_key.shared_with.to_string() + " with id:" + uuid)
            self.authenticated = True

    #Running in a thread
    def _forward_socket_handler(self, chan, dest):
        sock = socket()
        try:
            sock.connect(dest)
        except Exception as e:
            self.logger.error(f"Forwarding request to {dest} failed: {e}")
            return

        self.logger.info(
            f"Connected!  Tunnel open {chan.origin_addr} -> {chan.getpeername()} -> {dest}"
        )

        while not self.closing.is_set():
            r, w, x = select([sock, chan], [], [])
            if sock in r:
                data = sock.recv(1024)
                if len(data) == 0:
                    break
                chan.send(data)
            if chan in r:
                data = chan.recv(1024)
                if len(data) == 0:
                    break
                sock.send(data)
        chan.close()
        sock.close()
        self.logger.info(f"Tunnel closed from {chan.origin_addr}")

    #running in a thread
    def _forward_socket(self, tp, dest):
        while not self.closing.is_set():
            chan = tp.accept(1000)
            if chan is None:
                continue
            
            thread = threading.Thread(
                target=self._forward_socket_handler,
                args=(chan, dest),
                daemon=True,
            )
            thread.start()
            SSHNPDClient.threads.append(thread)

    def _reverse_ssh_client(self, ssh_list: list, private_key: str):
        local_port = ssh_list[0]
        port = ssh_list[1]
        username = ssh_list[2]
        hostname = ssh_list[3]
        if "\\" in username:
            username = username.split("/")[-1]
        self.logger.info("ssh session started for " + username + " @ " + hostname + " on port " + port)
        if self.ssh_client == None:
            ssh_client = SSHClient()
            ssh_client.load_system_host_keys(f"{self.ssh_path}/known_hosts")
            ssh_client.set_missing_host_key_policy(WarningPolicy())
            file_like = StringIO(private_key)
            paramiko_log = logging.getLogger("paramiko.transport")
            paramiko_log.setLevel(self.logger.level)
            paramiko_log.addHandler(logging.StreamHandler())
            self.ssh_client = ssh_client
        
        try:
            pkey = Ed25519Key.from_private_key(file_obj=file_like)
            self.ssh_client.connect(
                hostname=hostname,
                port=port,
                username=username,
                pkey=pkey,
                allow_agent=False,
                timeout=10,
                disabled_algorithms={"pubkeys": ["rsa-sha2-512", "rsa-sha2-256"]},
            )
            tp = self.ssh_client.get_transport()
            self.logger.info("Forwarding port " + local_port + " to " + hostname + ":" + port)
            tp.request_port_forward("", int(local_port))
            thread = threading.Thread(
                target=self._forward_socket,
                args=(tp, ("localhost", 22)),
                daemon=True,
            )
            thread.start()
            SSHNPDClient.threads.append(thread)
        
        #I'll end up doing more with this I think
        except  SSHException as e:
            raise(f'SSHError (Make sure you do not have another sshnpd running): $e')
        except Exception as e:
            raise(e)
        
        return "connected"
    
   

    def _generate_ssh_keys(self):
        # Generate SSH Keys
        self.logger.info("Generating SSH Keys")
        ed25519keypair = Ed25519PrivateKey.generate()
        ssh_private_key = ed25519keypair.private_bytes(
            encoding=serialization.Encoding.PEM, format=serialization.PrivateFormat.OpenSSH, encryption_algorithm=serialization.NoEncryption()
        ).decode("utf-8")
        
        ssh_public_key = ed25519keypair.public_key().public_bytes(
            encoding=serialization.Encoding.PEM, format=serialization.PublicFormat.SubjectPublicKeyInfo
        ).decode("utf-8")
        
        return (ssh_public_key, ssh_private_key)

    def _handle_ssh_public_key(self, ssh_public_key):
        # // Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
        filedata = ""
        
        if not os.path.isfile(f"{self.ssh_path}/authorized_keys"):
            open(f"{self.ssh_path}/authorized_keys", "a").close()
            
        with open(f"{self.ssh_path}/authorized_keys", "r") as read:
            filedata = read.read()
            if ssh_public_key not in filedata:
                with open(f"{self.ssh_path}/authorized_keys", "w") as write:
                    write.write(f"{filedata}\n{ssh_public_key}")
                self.logger.debug("key written" )

def main():
    parser = argparse.ArgumentParser("sshnpd")
    requiredNamed = parser.add_argument_group('required named arguments')
    requiredNamed.add_argument("-m", "--manager", dest="manager_atsign", type=str, help="Client Atsign (sshnp's atsign)", required=True)
    requiredNamed.add_argument("-a", "--atsign", dest="atsign", type=str, help="Device Atsign (sshnpd's atsign)", required=True)
    requiredNamed.add_argument("-d", "--device", dest="device", type=str, help="Device Name", required=True)
    optional = parser.add_argument_group('optional arguments')
    optional.add_argument("-u",  action='store_true', dest="username",  help="Username", default="default")
    optional.add_argument("-v", action='store_true', dest="verbose", help="Verbose")
    optional.add_argument("-s", action="store_true", dest="expecting_ssh_keys", help="SSH Keypair, use this if you want to use your own ssh keypair")
    
    args = parser.parse_args()

    sshnpd = SSHNPDClient(args.atsign, args.manager_atsign, args.device, args.username, args.verbose, args.expecting_ssh_keys)
    
    try:
        threading.Thread(target=sshnpd.start).start()
        while len(SSHNPDClient.threads) > 0:
            if not sshnpd.is_alive():
                sshnpd.join()
            else:
                sleep(10)
        
            
    except Exception as e:
        print(e)
        sshnpd.join()


if __name__ == "__main__":
    main()
