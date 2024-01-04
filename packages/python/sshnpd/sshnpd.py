#!/bin/env python3
import os, threading, getpass, json, logging, subprocess, argparse, errno
from io import StringIO
from queue import Empty, Queue
from time import sleep
from threading import Event

from select import select
from socket import socket, gethostbyname, gethostname, create_connection, error

from at_client import AtClient
from at_client.common import AtSign
from at_client.util import EncryptionUtil, KeysUtil
from at_client.common.keys import AtKey, Metadata, SharedKey
from at_client.connections.notification.atevents import AtEvent, AtEventType


class SocketConnector:
    _logger = logging.getLogger("sshrv | socket_connector")
    def __init__(self, server1_ip, server1_port, server2_ip, server2_port, verbose = False):
        self._logger.setLevel(logging.INFO)
        self._logger.addHandler(logging.StreamHandler())
        if verbose:
            self._logger.setLevel(logging.DEBUG)
        
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
        self.logger = logging.getLogger("sshrv")
        self.host = ""
        self.destination = destination
        self.local_ssh_port = local_port
        self.streaming_port = port
        self.socket_connector = None
        self.verbose = verbose

    def run(self):
        try:
            self.host = gethostbyname(gethostname())
            socket_connector = SocketConnector(self.host, self.local_ssh_port, self.destination, self.streaming_port, verbose=self.verbose)
            t1 = threading.Thread(target=socket_connector.connect)
            t1.start()
            self.socket_connector = t1
            return True
                
        except Exception as e:
            logging.error("SSHRV Error: " + str(e))
            
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
        self.at_client =    AtClient(AtSign(atsign), queue=Queue(maxsize=20), verbose=verbose)
        
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
        sshrv.run()
        self.rv = sshrv
        self.logger.info("sshrv started @ "  + hostname + " on port " + str(port))
        (public_key, private_key)= self._generate_ssh_keys(sessionId)
        private_key = private_key.replace("\n", "\\n")
        self._handle_ssh_public_key(public_key)
        data = f'{{"status":"connected","sessionId":"{sessionId}","ephemeralPrivateKey":"{private_key}"}}'
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
            ssh_response = self._reverse_ssh_client(ssh_list, private_key, uuid)
        
        if ssh_response:
            notify_response = self.at_client.notify(at_key, ssh_response, session_id=uuid)
            self.logger.info("sent ssh notification to " + at_key.shared_with.to_string() + " with id:" + uuid)
            self.authenticated = True
        if direct:
            self._ephemeral_cleanup(uuid)
        else:
            self._pem_cleanup(uuid)

    def _reverse_ssh_client(self, ssh_list: list, private_key: str, uuid : str):
        local_port = ssh_list[0]
        port = ssh_list[1]
        username = ssh_list[2]
        hostname = ssh_list[3]
        if "\\" in username:
            username = username.split("/")[-1]
        self.logger.info("ssh session started for " + username + " @ " + hostname + " on port " + port)
        filePath = f'{self.ssh_path}/tmp/.{uuid}'
        
        if not os.path.exists(f"{self.ssh_path}/tmp/"):
            os.makedirs(f"{self.ssh_path}/tmp/")
        
        pemFile = open(filePath, "w")
        if not private_key.endswith("\\n"):
            private_key += "\\n"  
              
        pemFile.write(private_key)
        pemFile.close()
        subprocess.run("chmod go-rwx " + filePath, shell=True)
        
        ssh_binary = subprocess.Popen(["ssh", 
                                       f"{username}@{hostname}",
                                       "-p", port, 
                                       "-R", f"{local_port}:localhost:22",
                                       "-t", "-t",
                                       "-i", filePath, 
                                       "-o", "StrictHostKeyChecking=accept-new", 
                                       "-o", "IdentitiesOnly=yes",
                                       "-o", "BatchMode=yes",
                                       "-o", "ExitOnForwardFailure=yes",
                                       "-f",
                                       "sleep 15"
                                       ],
                                      cwd="/usr/bin/",)
        
        stdout, stderr = ssh_binary.communicate()
        
        if ssh_binary.returncode != 0:
            self.logger.error("SSH Connection failed")
            self.logger.error(stderr.decode("utf-8"))
            raise Exception("Reverse SSH Connection failed (Legacy)")
        
        self.logger.info("SSH Connection established")
        return "connected"

    def _generate_ssh_keys(self, session_id):
        # Generate SSH Keys
        self.logger.info("Generating SSH Keys")
        if not os.path.exists(f"{self.ssh_path}/tmp/"):
            os.makedirs(f"{self.ssh_path}/tmp/")
            
        ssh_keygen = subprocess.Popen(
            ["ssh-keygen", "-t", "ed25519", "-a", "100", "-f", f"{session_id}_sshnp", "-q", "-N", ""],
            cwd=f'{self.ssh_path}/tmp/',
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        
        stdout, stderr = ssh_keygen.communicate()
        if ssh_keygen.returncode != 0:
            self.logger.error("SSH Key generation failed")
            self.logger.error(stderr.decode("utf-8"))
            return False
        
        self.logger.info("SSH Keys Generated")
        ssh_public_key = ""
        ssh_private_key = ""
        try:
            with open(f"{self.ssh_path}/tmp/{session_id}_sshnp.pub", 'r') as public_key_file:
                ssh_public_key = public_key_file.read()

            with open(f"{self.ssh_path}/tmp/{session_id}_sshnp", 'r') as private_key_file:
                ssh_private_key = private_key_file.read()
                
        except Exception as e:
            self.logger.error(e)
            return False
        
        return (ssh_public_key, ssh_private_key)

    def _ephemeral_cleanup(self, session_id):
        try:
            os.remove(f"{self.ssh_path}/tmp/{session_id}_sshnp.pub")
            os.remove(f"{self.ssh_path}/tmp/{session_id}_sshnp")
            self.logger.info("ephemeral ssh keys cleaned up")
        except Exception as e:
            self.logger.error(e)
    
    def _pem_cleanup(self, session_id):
        try:
            os.remove(f"{self.ssh_path}/tmp/.{session_id}")
            self.logger.info("pem file cleaned up")
        except Exception as e:
            self.logger.error(e)

    def _handle_ssh_public_key(self, ssh_public_key):
        # // Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
        writeKey = False
        filedata = ""
        with open(f"{self.ssh_path}/authorized_keys", "r") as read:
            filedata = read.read()
            if ssh_public_key not in filedata:
                writeKey = True
        if writeKey:
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
