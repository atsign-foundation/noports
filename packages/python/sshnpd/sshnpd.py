#!/usr/bin/env python3
import argparse
import errno
import getpass
import json
import logging
import os
import subprocess
import sys
import threading
from queue import Empty, Queue
from time import sleep

from socket import gethostbyname, create_connection, error

from at_client import AtClient
from at_client.common import AtSign
from at_client.util import EncryptionUtil, KeysUtil
from at_client.common.keys import AtKey, Metadata, SharedKey
from at_client.connections.notification.atevents import AtEvent, AtEventType


class SocketConnector:
    _logger = logging.getLogger("sshrv | socket_connector")

    def __init__(self, server1_ip, server1_port, server2_ip, server2_port, verbose=False):
        self._logger.setLevel(logging.INFO)
        self._logger.addHandler(logging.StreamHandler())
        if verbose:
            self._logger.setLevel(logging.DEBUG)
        # Create sockets for both servers
        self.socketA = create_connection((server1_ip, server1_port))
        self.socketB = create_connection((server2_ip, server2_port))
        self.socketA.setblocking(0)
        self.socketB.setblocking(0)
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
                            return
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
                            raise e
        except Exception as e:
            print("failed to connect")
            raise e

    def close(self):
        self.socketA.close()
        self.socketB.close()


class SSHRV:
    def __init__(self, destination, port, local_port=22, verbose=False):
        self.logger = logging.getLogger("sshrv")
        self.host = ""
        self.destination = destination
        self.local_ssh_port = local_port
        self.streaming_port = port
        self.socket_connector = None
        self.verbose = verbose

    def run(self):
        try:
            self.host = gethostbyname('localhost')
            socket_connector = SocketConnector(self.host, self.local_ssh_port, self.destination, self.streaming_port, verbose=self.verbose)
            t1 = threading.Thread(target=socket_connector.connect)
            t1.start()
            self.socket_connector = t1
            return True
        except Exception as e:
            raise e

    def is_alive(self):
        return self.socket_connector.is_alive()


class SSHNPDClient:
    def __init__(self, atsign, manager_atsign, device="default", username=None, verbose=False, expecting_ssh_keys=False):
        # AtClient Stuff
        self.atsign = atsign
        self.manager_atsign = manager_atsign
        self.device = device
        self.username = username
        self.device_namespace = f".{device}.sshnp"
        self.at_client = AtClient(AtSign(atsign), queue=Queue(maxsize=20), verbose=verbose)
        # SSH Stuff
        self.ssh_client = None
        self.rv = None
        self.expecting_ssh_keys = expecting_ssh_keys
        # Logger
        self.logger = logging.getLogger("sshnpd")
        self.logger.setLevel((logging.DEBUG if verbose else logging.INFO))
        self.logger.addHandler(logging.StreamHandler())
        # Directory Stuff
        home_dir = os.path.expanduser("~")
        self.ssh_path = f"{home_dir}/.ssh"

        self.threads = []
        self.encrypted_queue = Queue()

    def start(self):
        if self.username:
            self.set_username()

        self.threads.append(threading.Thread(target=self.at_client.start_monitor, args=(self.device_namespace,), daemon=True))
        self.threads.append(threading.Thread(target=self.handle_notifications,  daemon=True))
        self.threads.append(threading.Thread(target=self.handle_events,  daemon=True))

        for thread in self.threads:
            thread.start()

    def close(self):
        self.threads.clear()
        sys.exit()

    def is_alive(self):
        foreach_thread = [thread.is_alive() for thread in self.threads]
        return all(foreach_thread)

    def set_username(self):
        username = getpass.getuser()
        username_key = SharedKey(
            f"username.{self.device}.sshnp", AtSign(self.atsign), AtSign(self.manager_atsign))
        metadata = Metadata(iv_nonce=EncryptionUtil.generate_iv_nonce(), is_public=False, is_encrypted=True, is_hidden=False)
        username_key.metadata = metadata
        username_key.cache(-1, True)
        self.at_client.put(username_key, username)
        self.username = username

    # Running in a thread
    def handle_notifications(self):
        while True:
            try:
                at_event = self.at_client.queue.get(block=False)
                event_type = at_event.event_type
                event_data = at_event.event_data
                if event_type == AtEventType.UPDATE_NOTIFICATION:
                    self.encrypted_queue.put(at_event)
                if event_type != AtEventType.DECRYPTED_UPDATE_NOTIFICATION:
                    continue
                key = event_data["key"].split(":")[1].split(".")[0]
                decrypted_value = str(event_data["decryptedValue"])

                if key == "sshpublickey":
                    self.logger.debug(f'ssh Public Key received from ${event_data["from"]} notification id : ${event_data["id"]}')
                    self._handle_ssh_public_key(decrypted_value)
                    continue

                if key == 'ssh_request':
                    self.logger.debug(
                        f'ssh callback requested from {event_data["from"]} notification id : {event_data["id"]}')
                    try:
                        threading.Thread(target=self.direct_ssh, args=(at_event,)).start()
                    except Exception as e:
                        raise e
            except Empty:
                pass

    # Running in a thread
    def handle_events(self):
        while True:
            try:
                at_event = self.encrypted_queue.get(block=False)
                event_type = at_event.event_type
                if event_type == AtEventType.UPDATE_NOTIFICATION:
                    self.at_client.secondary_connection.execute_command(
                        "notify:remove:" + at_event.event_data["id"]
                    )
                self.at_client.handle_event(self.at_client.queue, at_event)
            except Empty:
                pass

    def direct_ssh(self, event: AtEvent):
        uuid = event.event_data["id"]
        ssh_list = json.loads(event.event_data["decryptedValue"])['payload']
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
        uuid = ssh_list['sessionId']
        at_key = AtKey(f"{uuid}", self.atsign)
        at_key.shared_with = AtSign(self.manager_atsign)
        at_key.metadata = metadata
        at_key.namespace = self.device_namespace
        hostname = ssh_list['host']
        port = ssh_list['port']
        session_id = ssh_list['sessionId']
        try:
            sshrv = SSHRV(hostname, port)
            sshrv.run()
            self.rv = sshrv
            self.logger.info("sshrv started @ " + hostname + " on port " + str(port))
            (public_key, private_key) = self.generate_ssh_keys(session_id)
            private_key = private_key.replace("\n", "\\n")
            self.handle_ssh_public_key(public_key)
            data = f'{{"status":"connected","sessionId":"{session_id}","ephemeralPrivateKey":"{private_key}"}}'
            signature = EncryptionUtil.sign_sha256_rsa(data, self.at_client.keys[KeysUtil.encryption_private_key_name])
            response = f'{{"payload":{data},"signature":"{signature}","hashingAlgo":"sha256","signingAlgo":"rsa2048"}}'
            self.at_client.notify(at_key, response, session_id=uuid)
            self.logger.info("sent ssh notification to " + at_key.shared_with.to_string() + " with id:" + uuid)
            self.ephemeral_cleanup(uuid)

        except Exception as e:
            self.logger.error(e)
            self.ephemeral_cleanup(uuid)

    def generate_ssh_keys(self, session_id):
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

    def ephemeral_cleanup(self, session_id):
        try:
            os.remove(f"{self.ssh_path}/tmp/{session_id}_sshnp.pub")
            os.remove(f"{self.ssh_path}/tmp/{session_id}_sshnp")
            self.logger.info("ephemeral ssh keys cleaned up")
        except Exception:
            self.logger.info("")

    def handle_ssh_public_key(self, ssh_public_key):
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
            self.logger.debug("key written")


def main():
    parser = argparse.ArgumentParser("sshnpd")
    requiredNamed = parser.add_argument_group('required named arguments')
    requiredNamed.add_argument("-m", "--manager", dest="manager_atsign", type=str, help="Client Atsign (sshnp's atsign)", required=True)
    requiredNamed.add_argument("-a", "--atsign", dest="atsign", type=str, help="Device Atsign (sshnpd's atsign)", required=True)
    requiredNamed.add_argument("-d", "--device", dest="device", type=str, help="Device Name", default="default")
    optional = parser.add_argument_group('optional arguments')
    optional.add_argument("-s", action="store_true", dest="expecting_ssh_keys", help="Add ssh key into authorized_keys", default=False)
    optional.add_argument("-u",  action='store_true', dest="username",  help="Username", default="default", required=True)
    optional.add_argument("-v", action='store_true', dest="verbose", help="Verbose")
    args = parser.parse_args()
    sshnpd = SSHNPDClient(args.atsign, args.manager_atsign, args.device, args.username, args.verbose, args.expecting_ssh_keys)
    thread = None
    while True:
        try:
            thread = threading.Thread(target=sshnpd.start)
            thread.start()
            while sshnpd.is_alive():
                sleep(3)
        except Exception as e:
            thread.join()
            sshnpd.close()
            print(e)
        print("Restarting sshnpd in 3 seconds..")
        sleep(3)


if __name__ == "__main__":
    main()
