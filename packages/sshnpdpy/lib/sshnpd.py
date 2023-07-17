# MVP


# Need to at_py
# need to setup a reverse ssh connection via notifications
# 1. monitor the atsign and while you wait for a notification, sync.
# 2. once recieved a notification send a reverse ssh connection to user
# 3. wait for an sshd connection
# 4. donezo (make sure to close the connection when users are done)

# need at_python, argparse
# plan to use bash scripts for most of the heavy lifting
# let's get this mvp out.
import base64
from io import StringIO
import json
import os
import argparse
import select
import subprocess
from queue import Empty, Queue
from socket import socket, AF_INET, SOCK_STREAM
from ssl import PROTOCOL_TLSv1_2, wrap_socket
import threading
from time import sleep
import uuid
from paramiko import SSHClient
from paramiko.rsakey import RSAKey

from at_client import AtClient
from at_client.common import AtSign
from at_client.common.keys import AtKey, SharedKey, Metadata
from at_client.connections.notification.atnotification import AtNotification
from at_client.connections.atmonitorconnection import AtMonitorConnection
from at_client.connections.notification.atevents import AtEvent, AtEventType

namespace = 'sshnp'


def handle_event(queue, client, ssh_path):
    private_key = ""
    sshPublicKey = ""
    ssh_notification_recieved = False
    while not ssh_notification_recieved:
        try:
            at_event = queue.get(block=False)
            client.handle_event(queue, at_event)
            event_type = at_event.event_type
            event_data = at_event.event_data
            if event_type == AtEventType.DECRYPTED_UPDATE_NOTIFICATION:
                key = event_data["key"]
                decrypted_value = str(event_data["decryptedValue"])
                if key == "privatekey":
                    print(
                        f'private key received from ${event_data["from"]} notification id : ${event_data["id"]}')
                    private_key = decrypted_value
                    continue

                if key == "sshpublickey":
                    print(
                        f'ssh Public Key received from ${event_data["from"]} notification id : ${event_data["id"]}')
                    sshPublicKey = decrypted_value
                    # // Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
                    writeKey = False
                    with open(f'{ssh_path}/authorized_keys', 'r') as read:
                        filedata = read.read()
                        if sshPublicKey not in filedata:
                            writeKey = True
                    with open(f'{ssh_path}/authorized_keys', 'w') as write:
                        if writeKey:
                            write.write(f'\n{sshPublicKey}')
                            print("key written")
                    continue

                if key == "sshd":
                    print(
                        f'ssh callback requested from ${event_data["from"]} notification id : ${event_data["id"]}')
                    ssh_notification_recieved = True

                    continue

                sleep(1)
        except Empty:
            pass


def ssh_handler(chan, host, port):
    sock = socket.socket()
    try:
        sock.connect((host, port))
    except Exception as e:
        print("Forwarding request to %s:%d failed: %r" % (host, port, e))
        return

    print(
        "Connected!  Tunnel open %r -> %r -> %r"
        % (chan.origin_addr, chan.getpeername(), (host, port))
    )
    while True:
        r, w, x = select.select([sock, chan], [], [])
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
    print("Tunnel closed from %r" % (chan.origin_addr,))


def reverse_forward_tunnel(server_port, remote_host, remote_port, ssh_client: SSHClient):
    transport = ssh_client.get_transport()
    transport.request_port_forward("", server_port)
    while True:
        chan = transport.accept(1000)
        if chan is None:
            continue
        thr = threading.Thread(
            target=ssh_handler, args=(chan, remote_host, remote_port)
        )
        thr.setDaemon(True)
        thr.start()


def ssh_callback(event: AtEvent, private_key: str, manager_atsign: str, device_atsign: str, device: str):
    uuid = uuid.uuid4()
    ssh_list = event.event_data["decryptedValue"].split(" ")
    metadata = Metadata(is_public=False, ttl=10000, ttr=-1,
                        is_encrypted=True, namespace_aware=True)
    at_key = AtKey(f'{uuid}.{device}', device_atsign)
    at_key.shared_with = manager_atsign
    at_key.metadata = metadata
    at_key.namespace = namespace
    local_port = ssh_list[0]
    port = ssh_list[1]
    username = ssh_list[2]
    hostname = ssh_list[3]
    if len(ssh_list) == 5:
        uuid = ssh_list[4]
        at_key = AtKey(f'{uuid}.{device}', device_atsign)
        at_key.shared_with = manager_atsign
        at_key.metadata = metadata
        at_key.namespace = namespace
    print("ssh session started for " + username +
          "@" + hostname + " on port " + port)
    ssh_client = SSHClient()
    with StringIO(private_key) as f:
        pkey = RSAKey.from_private_key(f)
    try:
        auth_result = ssh_client.connect(
            hostname, port, username, pkey=private_key)
        reverse_forward_tunnel(local_port, hostname, port, ssh_client)
    except Exception as e:
        print("Failed to connect to SSHClient")
        exit(1)


def main():
    parser = argparse.ArgumentParser("sshnpd")

    parser.add_argument('--manager', dest='manager_atsign', type=str)
    parser.add_argument('--atsign', dest='device_atsign', type=str)
    parser.add_argument('--device', dest='device', type=str)
    parser.add_argument('--username', dest='username', type=str)
    args = parser.parse_args()
    home_dir = ""
    if os.name == "posix":  # Unix-based systems (Linux, macOS)
        home_dir = os.path.expanduser("~")
    elif os.name == 'nt':  # Windows
        home_dir = os.path.expanduser("~")
    else:
        raise NotImplementedError("Unsupported operating system")

    commit_log_path = os.path.dirname(
        f'{home_dir}/.sshnp/{args.device_atsign}/storage/commitLog')
    download_path = os.path.dirname(f'{home_dir}/.sshnp/files')
    ssh_path = os.path.dirname(f'{home_dir}/.ssh/')

    event_queue = Queue(maxsize=10)
    client = AtClient(AtSign(args.device_atsign), queue=event_queue)

    threading.Thread(target=handle_event, args=(
        event_queue, client, ssh_path)).start()
    threading.Thread(target=client.start_monitor, args=()).start()

main()