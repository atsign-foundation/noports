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
import os, argparse, subprocess, base64


from at_client.common import AtClient, AtSign
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
#
bin_path = '/mnt/c/Users/xavie/atsign/sshnoports/packages/sshnpdpy/bin/' 
def monitor_process(popen):    
    for stdout_line in iter(popen.stdout.readline, ""):
        yield stdout_line 
    popen.stdout.close()
    return_code = popen.wait()
    if return_code:
        raise subprocess.CalledProcessError(return_code, [f'{bin_path}monitor.sh', args.manager_atsign[1:]])
    
challenge = ""
challenge_recieved = False
ssh_notification_recieved = False

popen = subprocess.Popen([f'{bin_path}monitor.sh', args.manager_atsign[1:]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, universal_newlines=True)
while not ssh_notification_recieved:
    if not challenge_recieved:
        for line in monitor_process(popen):
            if "data" in line:
                challenge = line.split("@data:")[1].strip()    
                print(challenge)
                challenge_recieved = True
                break
    else:    
        client = AtClient(AtSign(args.manager_atsign))
        client.pkam_authenticate()
        KeysUtil.load_keys(args.manager_atsign)
        privatekey = client.keys[KeysUtil.pkam_private_key_name]
        signature = EncryptionUtil.sign_sha256_rsa(challenge, privatekey)
        popen.stdin.write(f'pkam:{signature}\n')
        popen.stdin.flush()
        for notification in monitor_process(popen):
            print(notification)  







