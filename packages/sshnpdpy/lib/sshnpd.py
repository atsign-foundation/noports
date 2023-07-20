#!/usr/bin/env python3
from io import StringIO
import os, threading, argparse
from queue import Empty, Queue
from time import sleep
from uuid import uuid4
from paramiko import AutoAddPolicy, SSHClient
from paramiko.ssh_exception import NoValidConnectionsError
from paramiko.ed25519key import Ed25519Key

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
            event_type = at_event.event_type
            event_data = at_event.event_data
            
            #There's defintely a better way to do this
            #oh well
            #TODO: fix this
            if event_type == AtEventType.UPDATE_NOTIFICATION :
                queue.put(at_event)
                sleep(1)
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
            #Surely this can't be the best way to do this
            #probably something involving locks because I think both threads are trying to access the queue
            #the Main thread needs to access the queue AFTER the handle thread has finished with it
            if event_type == AtEventType.DECRYPTED_UPDATE_NOTIFICATION:
                queue.put(at_event)
                sleep(1) 
            else:
                print("decrypting event")
                client.handle_event(queue, at_event)
            
        except Empty:
            pass
        


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
          " @ " + hostname + " on port " + port)
    ssh_client = SSHClient()
    ssh_client.set_missing_host_key_policy(AutoAddPolicy())
    ssh_client.load_system_host_keys()
    #convert string to bytes
    file_like = StringIO(private_key)
    tp = ssh_client.get_transport()
    try:
        pkey = Ed25519Key(file_obj=file_like)
        auth_result = ssh_client.connect(
            hostname=hostname, port=port, username=username, pkey=pkey)
        tp.request_port_forward("", local_port)
        
        print("Forwarding port " + local_port + " to " + hostname + ":" + port)
    except NoValidConnectionsError as e:
        print("Failed to connect: ")
        for exception in e.errors:
            print(exception)
        exit(1)
    except Exception as e:
        print(e) 




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
    threading.Thread(target=client.start_monitor, args=(regex,)).start()
    threading.Thread(target=handle_events, args=(client.queue, client)).start()
    callbackArgs = handle_decryption(client.queue, client, ssh_path, args)
    ssh_callback(*callbackArgs)
    
if __name__ == "__main__":
    main()