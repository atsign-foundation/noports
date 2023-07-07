from os import environ
from pathlib import Path
from subprocess import Popen, PIPE
from typing import Tuple
from paramiko import SSHClient, SFTPClient, MissingHostKeyPolicy, AutoAddPolicy
from atsign_util import norm_atsign


class SSHNPClient:
    def __init__(
        self,
        client_atsign: str,
        host: str,
        device_atsign: str = None,
        public_key: str = None,
        private_key: str = None,
        policy: MissingHostKeyPolicy = AutoAddPolicy,
    ):
        self.binary = environ.get("SSHNP_BINARY", "sshnp")
        self.client_atsign = norm_atsign(client_atsign)
        self.device_atsign = (
            self.client_atsign if device_atsign is None else norm_atsign(device_atsign)
        )
        self.host = host
        self.public_key = (
            "sshnp{}.pub".format(self.device_atsign)
            if public_key is None
            else public_key
        )
        self.private_key = (
            (Path.home() / ".ssh" / "sshnp{}".format(self.device_atsign))
            if private_key is None
            else private_key
        )
        self.policy = policy

    def _connect_sshnp(self, args: Tuple[str]) -> str:
        """
        Runs sshnp and returns the output of the command.
        """
        p = Popen(
            [
                self.binary,
                "-h",
                self.host,
                "-f",
                self.client_atsign,
                "-t",
                self.device_atsign,
                "-s",
                self.public_key,
                *args,
            ],
            stdin=PIPE,
            stdout=PIPE,
            stderr=PIPE,
        )
        out, err = p.communicate()
        exit_code = p.wait()
        if exit_code != 0:
            raise Exception(
                f"SSHNP exited with code {exit_code}: {err.decode('utf-8')}"
            )
        return out.decode("utf-8")

    def connect_ssh(self, device_name: str = "default") -> SSHClient:
        """
        Returns an SSHClient connected to the device.
        """
        sshnp_out = self._connect_sshnp(("-d", device_name)).split(" ")
        username = [s for s in sshnp_out if "@" in s][0].split("@")[0]
        port = sshnp_out[sshnp_out.index("-p") + 1]
        ssh = SSHClient()
        ssh.set_missing_host_key_policy(self.policy)
        ssh.connect(
            "localhost",
            port=port,
            key_filename=str(Path.home() / ".ssh" / self.private_key),
            username=username,
        )
        return ssh

    def connect_sftp(self, device_name: str = "default") -> SFTPClient:
        """
        Returns an SFTPClient connected to the device.
        """
        ssh = self.connect_ssh(device_name=device_name)
        return ssh.open_sftp()
