## MVP

## Need to at_py
## need to setup a reverse ssh connection via notifications
    ## 1. monitor the atsign and while you wait for a notification, sync.
    ## 2. once recieved a notification send a reverse ssh connection to user
    ## 3. wait for an sshd connection
    ## 4. donezo (make sure to close the connection when users are done)
    
## need at_python, argparse
## plan to use bash scripts for most of the heavy lifting
##  let's get this mvp out.
import json
import os, argparse, subprocess
from socket import socket, AF_INET, SOCK_STREAM
from ssl import PROTOCOL_TLSv1_2, wrap_socket
from time import sleep
import uuid


from at_client.common import AtClient, AtSign
from at_client.common.keys import AtKey, SharedKey
from at_client.util import EncryptionUtil, KeysUtil

namespace = 'sshnp'
parser = argparse.ArgumentParser("sshnpd")

parser.add_argument('--managerAtsign', dest='manager_atsign', type=str)
parser.add_argument('--deviceAtsign', dest='device_atsign', type=str)
parser.add_argument('--device', dest='device', type=str)
parser.add_argument('--username', dest='username', type=str)
args = parser.parse_args()
home_dir = ""
if os.name == "posix":  # Unix-based systems (Linux, macOS)
    home_dir =  os.path.expanduser("~")
elif os.name == 'nt':  # Windows
    home_dir =  os.path.expanduser("~")
else:
    raise NotImplementedError("Unsupported operating system")

commit_log_path = os.path.dirname(f'{home_dir}/.sshnp/{args.device_atsign}/storage/commitLog')
download_path = os.path.dirname(f'{home_dir}/.sshnp/files')
ssh_path = os.path.dirname(f'{home_dir}/.ssh/')
    
privatekey = ""
sshPublicKey = ""
ssh_notification_recieved = False
client = AtClient(AtSign(args.device_atsign))
secondary = client.secondary_connection
secondary.connect()
secondary.execute_command(f'monitor {args.device}\.{namespace}@')

while not ssh_notification_recieved:
    response = secondary.parse_raw_response(secondary.read())
    raw_data = response.get_raw_data_response().strip(": \t\n\r")
    notification = json.loads(raw_data)
    
    if notification['id'] == "-1":
        sleep(1)
        continue
    
    keyName = notification['key'].split(":")[1].split(".")[0]
    if keyName == "privatekey":
        print(f'private key received from ${notification["from"]} notification id : ${notification["id"]}')
        privatekey = notification['value']
        continue
    
    if keyName == "sshpublickey":
        try:
            print(f'ssh Public Key received from ${notification["from"]} notification id : ${notification["id"]}')
            sshPublicKey = notification['value']
            #// Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
            with open(f'{ssh_path}/authorized_keys', 'r') as file:
                filedata = file.read()
                if sshPublicKey not in filedata:
                    file.write(sshPublicKey)
            continue
        except: 
            print("Error writing to authorized_keys file")
            continue
    
    if keyName == "sshd":
        print(f'ssh callback requested from ${notification["from"]} notification id : ${notification["id"]}')
        ssh_notification_recieved = True
        session_id = uuid.uuid4()
        shared_key = SharedKey(f'{keyName}.{args.device}', shared_by=AtSign(args.device_atsign), shared_with=AtSign(args.manager_atsign))
        shared_key.set_namespace(namespace)
        decrypted_value = client.get(shared_key)
        sshList = decrypted_value.split(" ")
        
        continue
    
    sleep(1)
