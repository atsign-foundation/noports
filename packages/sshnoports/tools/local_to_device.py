from dotenv import load_dotenv
from os import getenv
from os import path as os_path

# first install sshnoports_sdk_python from packages/sshnoports_sdk_python using poetry
from sshnoports_sdk_python import SSHNPClient, LocalPackageSource

script_dir = os_path.dirname(os_path.realpath(__file__))

load_dotenv()

client = SSHNPClient(
    client_atsign=getenv("FROM"),
    device_atsign=getenv("TO"),
    host=getenv("HOST"),
    public_key=getenv("SSH_PUBLIC_KEY"),
)

client.connect(getenv("DEVICE"))

client.update_sshnpd(LocalPackageSource(os_path.join(script_dir, "..", "..", "..")))
client.restart_all_services()
