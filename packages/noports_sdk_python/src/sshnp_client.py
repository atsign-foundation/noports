from os import environ, path, listdir
from subprocess import Popen, PIPE
from typing import Tuple, Iterator
from datetime import datetime

from paramiko import SSHClient as _SSHClient, MissingHostKeyPolicy, AutoAddPolicy
from paramiko.sftp_client import SFTPClient as _SFTPClient

# Relative imports
from .util import norm_atsign, filter_none
from .package_source import (
    PackageSource,
    LocalPackageSource,
    GitPackageSource,
    ReleasePackageSource,
    ArchivePackageSource,
)


class SFTPClient(_SFTPClient):
    def put(self, source: str, target: str):
        try:
            super().put(source, target)
        except IOError as e:
            print(f"Error putting file [{source} -> {target}]: {e}")

    def put_item(self, source: str, target: str, item: str):
        self.put(path.join(source, item), path.join(target, item))

    def mkdir(self, target: str):
        try:
            super().mkdir(target)
        except IOError as e:
            print(f"Error creating directory [{target}]: {e}")

    def put_dir(self, source: str, target: str, recursive: bool = True):
        self.mkdir(target)
        for item in listdir(path.abspath(source)):
            if path.isfile(path.join(source, item)):
                self.put_item(source, target, item)
            elif path.isdir(path.join(source, item)):
                self.mkdir(path.join(target, item))
                if recursive:
                    self.put_dir(path.join(source, item), path.join(target, item))


class SSHClient(_SSHClient):
    def open_sftp(self) -> SFTPClient:
        return SFTPClient.from_transport(self.get_transport())

    def line_buffer_command(
        self,
        command: str,
        bufsize=-1,
        timeout=None,
        get_pty=False,
        environment=None,
    ) -> Iterator[str]:
        _, _out, _ = self.exec_command(command, bufsize, timeout, get_pty, environment)
        line_buf = ""
        while not _out.channel.exit_status_ready():
            line_buf += _out.read(1).decode("utf-8")
            if line_buf.endswith("\n"):
                yield line_buf
                line_buf = ""

    def run_command(self, command: str) -> None:
        for line in self.line_buffer_command(command):
            print(line, end="")
        return


class SSHNPClient:
    def __init__(
        self,
        client_atsign: str,
        host: str,
        device_atsign: str = None,
        public_key: str = None,
        policy: MissingHostKeyPolicy = AutoAddPolicy,
    ):
        self.binary = environ.get("SSHNP_BINARY", "sshnp")
        self.client_atsign = norm_atsign(client_atsign)
        self.device_atsign = (
            self.client_atsign if device_atsign is None else norm_atsign(device_atsign)
        )
        self.host = host
        self.public_key = public_key
        self.policy = policy

    def _sshnp(self, *args) -> str:
        """
        Run sshnp with the given arguments.
        :param list args:
            The arguments to pass to sshnp.
        :return:
            The stdout of sshnp.
        """
        p = Popen(
            filter_none(
                [
                    self.binary,
                    "-h",
                    self.host,
                    "-f",
                    self.client_atsign,
                    "-t",
                    self.device_atsign,
                    "-s" if self.public_key is not None else None,
                    self.public_key,
                    *args,
                ]
            ),
            stdin=PIPE,
            stdout=PIPE,
            stderr=PIPE,
        )
        _stdout, _stderr = p.communicate()
        exit_code = p.wait()
        if exit_code != 0:
            raise Exception(
                f"SSHNP exited with code {exit_code}: {_stderr.decode('utf-8')}"
            )
        return _stdout.decode("utf-8")

    def connect(
        self, device_name: str = "default", *sshnp_args, **ssh_args
    ) -> SSHClient:
        """
        SSH connect to a device

        :param str device_name:
            the name of the device to connect to
        :param list sshnp_args:
            additional arguments to pass to sshnp
        :param dict ssh_args:
            additional arguments to pass to paramiko.SSHClient.connect

        :return:
            A paramiko.SSHClient connected to the device
        """
        sshnp_sout = self._sshnp("-d", device_name, *sshnp_args).split()

        sshnp_conn = [s for s in sshnp_sout if "@" in s][0].split("@")
        sshnp_port = sshnp_sout[sshnp_sout.index("-p") + 1]
        sshnp_pkey = sshnp_sout[sshnp_sout.index("-i") + 1]

        client = SSHClient()
        client.set_missing_host_key_policy(self.policy)
        client.connect(
            sshnp_conn[1],
            port=sshnp_port,
            key_filename=sshnp_pkey,
            username=sshnp_conn[0],
            *ssh_args,
        )

        self.client = client
        return client

    def is_connected(self) -> bool:
        """
        Check if the client is connected to a device.

        :return:
            True if the client is connected to a device, False otherwise.
        """
        return hasattr(self, "client") and self.client is not None

    def get_service_list(self, use_cache: bool = True) -> list[Tuple[str, str]]:
        """
        Get a list of sshnpd services running on the device.

        :return:
            A list of services running on the device.
        """
        if use_cache and hasattr(self, "_service_list"):
            return self._service_list

        if not self.is_connected():
            raise Exception("SSHNPClient not connected to device")

        # TODO read with SFTP
        _, _out, _ = self.client.exec_command("cat ~/.sshnpd/.service_list")
        lines = _out.read().decode("utf-8").strip().split("\n")
        services = [tuple(line.strip().split()) for line in lines]

        self._service_list = services
        return services

    def download_package_source(self, source: PackageSource) -> str:
        """
        Downloads a package source to the device.

        :param PackageSource source:
            The package source to download.
        :return:
            The path to the downloaded package source.
        """
        if not self.is_connected():
            raise Exception("SSHNPClient not connected to device")

        sftp = self.client.open_sftp()
        sftp.chdir(".")

        temp_path = int(datetime.utcnow().timestamp())

        # These types need to be built on the device
        if type(source) is LocalPackageSource or type(source) is GitPackageSource:
            if type(source) is GitPackageSource:
                # TODO download Git repo
                pass
            source_path = path.join(source.path, "packages", "sshnoports")
            target_path = path.join(sftp.getcwd(), ".atsign", "temp", str(temp_path))
            sftp.mkdir(target_path)

            sftp.put_dir(
                path.join(source_path, "bin"),
                path.join(target_path, "bin"),
            )
            sftp.put_dir(
                path.join(source_path, "lib"),
                path.join(target_path, "lib"),
            )
            sftp.put_dir(
                path.join(source_path, "templates"),
                path.join(target_path, "templates"),
            )
            sftp.put_dir(
                path.join(source_path, "scripts"),
                path.join(target_path, "scripts"),
            )

            sftp.put(
                path.join(source_path, "pubspec.yaml"),
                path.join(target_path, "pubspec.yaml"),
            )
            sftp.put(
                path.join(source_path, "pubspec.lock"),
                path.join(target_path, "pubspec.lock"),
            )

            self.client.run_command(f"dart pub get -C {target_path}"),
            self.client.run_command(
                f"dart compile exe {target_path}/bin/sshnp.dart -o {target_path}/sshnp"
            )
            self.client.run_command(
                f"dart compile exe {target_path}/bin/sshnpd.dart -o {target_path}/sshnpd"
            )
            self.client.run_command(
                f"dart compile exe {target_path}/bin/sshrv.dart -o {target_path}/sshrv"
            )
            self.client.run_command(
                f"dart compile exe {target_path}/bin/activate_cli.dart -o {target_path}/at_activate"
            )
        # These types can be downloaded directly to the device
        elif (
            type(source) is ArchivePackageSource or type(source) is ReleasePackageSource
        ):
            if type(source) is ReleasePackageSource:
                temp_path = source.version
                # TODO download release from repo
                pass
            raise NotImplementedError
        else:
            raise TypeError
        return target_path

    def setup_main_binaries(self, source: str) -> None:
        """
        Sets up the main binaries on the device.

        :param str source:
            The path to where the binaries are located.
        """
        if not self.is_connected():
            raise Exception("SSHNPClient not connected to device")
        sftp = self.client.open_sftp()
        main_binaries = ["sshnpd", "sshrv", "at_activate"]
        for binary in main_binaries:
            sftp.rename(
                path.join(source, binary),
                path.join("~/.local/bin", binary),
            )

    def restart_service(self, service_name: str):
        """
        Restarts a service on the device.

        :param str service_name:
            The name of the service to restart.
        """
        _, _out, _ = self.client.exec_command(
            f"pgrep -P $(pgrep -U $(whoami) -f bin/{service_name}$)"
        )
        sshnpd_pid = _out.read().decode("utf-8").strip()
        self.client.exec_command(f"kill -9 {sshnpd_pid}")

    def update_service(self, service_name: str, source: PackageSource) -> None:
        src = self.download_package_source(source)
        self.setup_main_binaries(src)
        self.restart_service(service_name)
