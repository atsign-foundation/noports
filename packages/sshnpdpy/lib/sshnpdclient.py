from io import StringIO
import logging
import os, threading
import subprocess
from queue import Empty, Queue
from time import sleep
from uuid import uuid4
from paramiko import AutoAddPolicy, SSHClient
from paramiko.ed25519key import Ed25519Key


from socket import socket
from select import select

from at_client import AtClient
from at_client.common import AtSign
from at_client.util import EncryptionUtil
from at_client.common.keys import AtKey, Metadata, SharedKey
from at_client.connections.notification.atevents import AtEvent, AtEventType

#TODO: Figure out all the exception stuff later


class SSHNPDClient:
    #Current opened threads (TODO: clean up threads)
    threads = []
    
    def __init__(self, atsign, manager_atsign, device, username):
        self.atsign = atsign
        self.manager_atsign = manager_atsign
        self.device = device
        self.username = username
        self.at_client = AtClient(AtSign(atsign), queue=Queue(maxsize=20))
        self.device_namespace = f".{device}.sshnp"
        self.authenticated = False
        home_dir = ""
        if os.name == "posix":  # Unix-based systems (Linux, macOS)
            home_dir = os.path.expanduser("~")
        elif os.name == "nt":  # Windows
            home_dir = os.path.expanduser("~")
        else:
            raise NotImplementedError("Unsupported operating system")
        self.ssh_path = f"{home_dir}/.ssh"
        
    def start(self):
        username_key = SharedKey(
        "username", AtSign(self.atsign), AtSign(self.manager_atsign))
        self.at_client.put(username_key, self.username)
        threading.Thread(target=self.at_client.start_monitor, args=(self.device_namespace,)).start()
        event_thread = threading.Thread(target=self._handle_events, args=(self.at_client.queue,))
        event_thread.start()
        SSHNPDClient.threads.append(event_thread)
        self._handle_notifications(self.at_client.queue, self.sshnp_callback)
        
        
    def cleanup_threads(self):
        self.at_client.stop_monitor()
        for thread in self.threads:
            thread.join()

    
    def _handle_notifications(self, queue: Queue, callback):
        private_key = ""
        sshPublicKey = ""
        ssh_notification_recieved = False
        while not ssh_notification_recieved or sshPublicKey == "" or private_key == "":
            try:
                at_event = queue.get(block=False)
                event_type = at_event.event_type
                event_data = at_event.event_data

                # There's defintely a better way to do this
                # oh well
                # TODO: fix this
                
                if event_type == AtEventType.UPDATE_NOTIFICATION:
                    queue.put(at_event)
                    sleep(1)
                if event_type != AtEventType.DECRYPTED_UPDATE_NOTIFICATION:
                    continue
                key = event_data["key"].split(":")[1].split(".")[0]
                decrypted_value = str(event_data["decryptedValue"])
                if key == "privatekey":
                    # print(
                    #     f'private key received from ${event_data["from"]} notification id : ${event_data["id"]}')
                    private_key = decrypted_value
                    continue

                if key == "sshpublickey":
                    # print(
                    # f'ssh Public Key received from ${event_data["from"]} notification id : ${event_data["id"]}')
                    sshPublicKey = decrypted_value
                    # // Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
                    writeKey = False
                    with open(f"{self.ssh_path}/authorized_hosts", "r") as read:
                        filedata = read.read()
                        if sshPublicKey not in filedata:
                            writeKey = True
                    with open(f"{self.ssh_path}/authorized_hosts", "w") as write:
                        if writeKey:
                            write.write(f"\n{sshPublicKey}")
                            print("key written")
                    continue

                if key == "sshd":
                    # print(
                    #     f'ssh callback requested from {event_data["from"]} notification id : {event_data["id"]}')
                    ssh_notification_recieved = True
                    callbackArgs = [
                        at_event,
                        private_key,
                    ]

            except Empty:
                pass
        try:
            callback(*callbackArgs)
        except Exception as e:
            raise e


    def _handle_events(self, queue: Queue):
        while True:
            try:
                at_event = queue.get(block=False)
                event_type = at_event.event_type
                # Surely this can't be the best way to do this
                # probably something involving locks because I think both threads are trying to access the queue
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


    def _reverse_ssh_exec(self, ssh_list: list, private_key, sessionID):
        local_port = ssh_list[0]
        port = ssh_list[1]
        username = ssh_list[2]
        hostname = ssh_list[3]
        filename = f"/tmp/.{uuid4()}"
        exitCode = 0
        if not private_key.endswith("\n"):
            private_key += "\n"
        with open(filename, "w") as file:
            file.write(private_key)
            subprocess.run(["chmod", "go-rwx", filename])
        args = [
            "ssh",
            f"{username}@{hostname}",
            "-p",
            port,
            "-i",
            filename,
            "-R",
            f"{local_port}:localhost:22",
            "-t",
            "-o",
            "StrictHostKeyChecking=accept-new",
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            "BatchMode=yes",
            "-o",
            "ExitOnForwardFailure=yes",
            "-v",
        ]
        try:
            process = subprocess.Popen(
                args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
            )
            stdout, stderr = process.communicate()
            exitCode = process.returncode
            if exitCode != 0:
                print("ssh session failed for " + username)
            else:
                print(
                    "ssh session started for "
                    + username
                    + "@"
                    + hostname
                    + " on port "
                    + port
                )
            os.remove(filename)
        except Exception as e:
            print(e)

        return exitCode == 0


    def _forward_socket_handler(self, chan, dest):
        sock = socket()
        try:
            sock.connect(dest)
        except Exception as e:
            print(f"Forwarding request to {dest} failed: {e}")
            return

        print(
            f"Connected!  Tunnel open {chan.origin_addr} -> {chan.getpeername()} -> {dest}"
        )

        while True:
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
        print(f"Tunnel closed from {chan.origin_addr}")


    def _forward_socket(self, tp, dest):
        while True:
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
        print("ssh session started for " + username + " @ " + hostname + " on port " + port)
        ssh_client = SSHClient()
        ssh_client.load_system_host_keys(f"{self.ssh_path}/known_hosts")
        ssh_client.set_missing_host_key_policy(AutoAddPolicy())
        file_like = StringIO(private_key)
        paramiko_log = logging.getLogger("paramiko.transport")
        paramiko_log.setLevel(logging.DEBUG)
        paramiko_log.addHandler(logging.StreamHandler())
        try:
            pkey = Ed25519Key.from_private_key(file_obj=file_like)
            ssh_client.connect(
                hostname=hostname,
                port=port,
                username=username,
                pkey=pkey,
                allow_agent=False,
                timeout=10,
                disabled_algorithms={"pubkeys": ["rsa-sha2-512", "rsa-sha2-256"]},
            )
            tp = ssh_client.get_transport()
            print("Forwarding port " + local_port + " to " + hostname + ":" + port)
            tp.request_port_forward("", int(local_port))
            thread = threading.Thread(
                target=self._forward_socket,
                args=(tp, ("localhost", 22)),
                daemon=True,
            )
            thread.start()
            SSHNPDClient.threads.append(thread)
        
        #I'll end up doing more with this I think
        except Exception as e:
            raise(e)
        return True


    def sshnp_callback(
        self,
        event: AtEvent,
        private_key,
    ):
        uuid = event.event_data["id"]
        ssh_list = event.event_data["decryptedValue"].split(" ")
        iv_nonce = EncryptionUtil.generate_iv_nonce()
        metadata = Metadata(
            ttl=10000,
            ttr=-1,
            iv_nonce=iv_nonce,
        )
        at_key = AtKey(f"{uuid}.", self.atsign)
        at_key.shared_with = AtSign(self.manager_atsign)
        at_key.metadata = metadata
        at_key.namespace = self.device_namespace
        if len(ssh_list) == 5:
            uuid = ssh_list[4]
            at_key = AtKey(f"{uuid}", self.atsign)
            at_key.shared_with = AtSign(self.manager_atsign)
            at_key.metadata = metadata
            at_key.namespace =self.device_namespace
        
        ssh_auth = self._reverse_ssh_client(ssh_list, private_key)
        
        if ssh_auth:
            response = self.at_client.notify(at_key, "connected")
            print("sent ssh notification to " + at_key.shared_with.to_string())
            self.authenticated = True
            