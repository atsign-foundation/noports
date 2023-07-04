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

import os, argparse

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
keys_path = os.path.dirname(f'{home_dir}/.atsign/keys')








