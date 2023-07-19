# MVP
from io import StringIO
import os, threading, argparse, select, socket
from queue import Empty, Queue
from time import sleep
from uuid import uuid4
from paramiko import SSHClient, SSHException
from paramiko.ssh_exception import NoValidConnectionsError
from paramiko.rsakey import RSAKey

from at_client import AtClient
from at_client.common import AtSign
from at_client.common.keys import AtKey, Metadata
from at_client.connections.notification.atevents import AtEvent, AtEventType

namespace = 'sshnp'


def handle_decryption(queue:Queue, client:AtClient, ssh_path, args: argparse.ArgumentParser):
    private_key = ""
    sshPublicKey = ""
    ssh_notification_recieved = False
    while not ssh_notification_recieved:
        try:
            at_event = queue.get(block=False)
            print("event received")
            event_type = at_event.event_type
            event_data = at_event.event_data
            
            #There's defintely a better way to do this
            #oh well
            #TODO: fix this
            if event_type == AtEventType.UPDATE_NOTIFICATION :
                queue.put(at_event)
            if event_type != AtEventType.DECRYPTED_UPDATE_NOTIFICATION :
                continue
            key = event_data["key"].split(":")[1].split(".")[0]
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
                callbackArgs = [at_event, private_key, args.manager_atsign, args.device_atsign, args.device]
                return callbackArgs

        except Empty:
            pass

def handle_events(queue:Queue, client: AtClient):
    while(True):
        try:
            at_event = queue.get(block=False)
            event_type = at_event.event_type
            if event_type != AtEventType.DECRYPTED_UPDATE_NOTIFICATION:
                client.handle_event(queue, at_event)
            
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
    uuid = uuid4()
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
    
    file_like = StringIO(private_key)
    try:
        auth_result = ssh_client.connect(
            hostname, port, username, pkey=file_like)
        print("Forwarding port " + local_port + " to " + hostname + ":" + port)
        reverse_forward_tunnel(local_port, hostname, port, ssh_client)
    except NoValidConnectionsError as e:
        print("Failed to forward port: ")
        for exception in e.errors:
            print(exception)
        exit(1)
    except Exception:
        print("Failed to create SSHClient")


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
    callbackArgs = []
    event_queue = Queue(maxsize=20)
    client = AtClient(AtSign(args.device_atsign), queue=event_queue)
    regex = ""
    monitor = threading.Thread(target=client.start_monitor, args=(regex,))
    monitor.start()
    event = threading.Thread(target=handle_events, args=(client.queue, client))
    event.start()
    callbackArgs = handle_decryption(client.queue, client, ssh_path, args)
    
    
if __name__ == "__main__":
    main()