from sshnp_client import SSHNPClient
from typing import Tuple
from paramiko import MissingHostKeyPolicy, AutoAddPolicy, SFTPClient, SSHClient


class SSHNPDManager(SSHNPClient):
    def __init__(
        self,
        client_atsign: str,
        host: str,
        device_atsign: str = None,
        public_key: str = None,
        private_key: str = None,
        policy: MissingHostKeyPolicy = AutoAddPolicy,
        device_name: str = "default",
    ):
        super().__init__(
            client_atsign=client_atsign,
            host=host,
            device_atsign=device_atsign,
            public_key=public_key,
            private_key=private_key,
            policy=policy,
        )
        self.ssh = super().connect_ssh(device_name=device_name)

    def run(self, command: str) -> Tuple[str, str]:
        """
        Runs a command on the device and returns the output.
        """
        stdin, stdout, stderr = self.ssh.exec_command(command)
        return stdout.read().decode("utf-8"), stderr.read().decode("utf-8")

    def sftp(self) -> SFTPClient:
        """
        Returns an SFTP client for the device.
        """
        return self.ssh.open_sftp()

    def close(self) -> None:
        """
        Closes the connection to the device.
        """
        self.ssh.close()
