#!/usr/bin/env python3
from io import StringIO
import os, threading, argparse
import subprocess
from queue import Empty, Queue
from time import sleep
from uuid import uuid4
from paramiko import AutoAddPolicy, SSHClient
from paramiko.ssh_exception import NoValidConnectionsError
from paramiko.ed25519key import Ed25519Key

from at_client import AtClient
from at_client.common import AtSign
from at_client.util import EncryptionUtil
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
                    f'ssh callback requested from {event_data["from"]} notification id : {event_data["id"]}')
                ssh_notification_recieved = True
                callbackArgs = [at_event, client, private_key, args.manager_atsign, args.device_atsign, args.device, ssh_path]
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
                if event_type == AtEventType.UPDATE_NOTIFICATION:
                    client.secondary_connection.execute_command("notify:remove:" + at_event.event_data["id"])
                client.handle_event(queue, at_event)
        except Empty:
            pass
        
def reverse_ssh_exec(ssh_list: list, private_key, sessionID):
    local_port = ssh_list[0]
    port = ssh_list[1]
    username = ssh_list[2]
    hostname = ssh_list[3]
    filename = f'/tmp/.{uuid4()}'
    exitCode = 0
    if not private_key.endswith('\n'):
        private_key += '\n'
    with open(filename, 'w') as file:
        file.write(private_key)
        subprocess.run(["chmod", "go-rwx", filename])
    args = ["ssh", f"{username}@{hostname}", '-p', port, "-i", filename, "-R", f"{local_port}:localhost:22", 
            "-t", '-o', 'StrictHostKeyChecking=accept-new',
            '-o', 'IdentitiesOnly=yes',
            '-o', 'BatchMode=yes',
            '-o', 'ExitOnForwardFailure=yes',
            "sleep", "15"]
    try:
        process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        exitCode = process.returncode
        if exitCode != 0:
            print("ssh session failed for " + username)
        else: 
            print("ssh session started for " + username@hostname + " on port " + port)
        os.remove(filename)
    except Exception as e:
        print(e)
    
    return exitCode == 0
        
    


def reverse_ssh_client(ssh_list: list, private_key: str, ssh_path: str):
    local_port = ssh_list[0]
    port = ssh_list[1]
    username = ssh_list[2]
    hostname = ssh_list[3]
    print("ssh session started for " + username +
          " @ " + hostname + " on port " + port)
    ssh_client = SSHClient()
    ssh_client.load_system_host_keys(f'{ssh_path}/known_hosts')
    ssh_client.set_missing_host_key_policy(AutoAddPolicy())
    file_like = StringIO(private_key)

    try:        
        pkey = Ed25519Key.from_private_key(file_obj=file_like)
        ssh_client.connect(
            hostname=hostname, port=port, username=username, pkey=pkey, allow_agent=False, look_for_keys=False, disabled_algorithms={"pubkeys":["rsa-sha2-512", "rsa-sha2-256"]})
        tp = ssh_client.get_transport()
        tp.request_port_forward("", local_port)
        print("Forwarding port " + local_port + " to " + hostname + ":" + port)
    except NoValidConnectionsError as e:
        print("Failed to connect: ")
        for exception in e.errors:
            print(exception)
        return False
    except Exception as e:
        print(e) 
        return False
    return True
    
        
def sshnp_callback(event: AtEvent, at_client: AtClient, private_key, manager_atsign, device_atsign, device, ssh_path):
    uuid = event.event_data["id"]
    ssh_list = event.event_data["decryptedValue"].split(" ")
    iv_nonce = EncryptionUtil.generate_iv_nonce()
    metadata = Metadata(is_public=False, ttl=10000, ttr=-1,
                        is_encrypted=True, namespace_aware=True, iv_nonce=iv_nonce)
    at_key = AtKey(f'{uuid}.', device_atsign)
    at_key.shared_with = AtSign(manager_atsign)
    at_key.metadata = metadata
    at_key.namespace = f"{device}.sshnp"
    if len(ssh_list) == 5:
        uuid = ssh_list[4]
        at_key = AtKey(f'{uuid}', device_atsign)
        at_key.shared_with = AtSign(manager_atsign)
        at_key.metadata = metadata
        at_key.namespace = f".{device}.sshnp"
    
    ssh_auth = reverse_ssh_exec(ssh_list, private_key, uuid)
    if ssh_auth:
        result = at_client.notify(at_key, 'connected')
        print("sent ssh notification to " + at_key.shared_with.to_string() + "\n result: " + result)
        return True
    else:
        print("ssh failed")
        return False
    
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
    regex = f"{namespace}"
    threading.Thread(target=client.start_monitor, args=(regex,)).start()
    threading.Thread(target=handle_events, args=(client.queue, client)).start()
    callbackArgs = handle_decryption(client.queue, client, ssh_path, args)
    ssh_connection  = sshnp_callback(*callbackArgs) 
    while not ssh_connection:
        sleep(3)
        callbackArgs = handle_decryption(client.queue, client, ssh_path, args)
        ssh_connection  = sshnp_callback(*callbackArgs)
    
        
if __name__ == "__main__":
    main()
    
    
    
    
    
    