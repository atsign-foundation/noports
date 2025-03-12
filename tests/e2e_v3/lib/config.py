from argparse import ArgumentParser
from typing import cast
from collections.abc import Sequence
from lib.version import Version


class Config:
    client_atsign: str
    daemon_atsign: str
    socket_rendezvous_atsign: str
    at_directory_host: str
    tests_to_run: list[str]
    daemon_versions: list[Version] = []
    client_versions: list[Version] = []
    relay_versions: list[Version] = []
    remote_username: str
    daemon_start_wait: int
    max_concurrency: int
    recompile: bool

    def __init__(self, args: Sequence[str] | None = None):
        parser = ArgumentParser(description="E2E Test Runner")
        _ = parser.add_argument("client_atsign", help="Client atsign")
        _ = parser.add_argument("daemon_atsign", help="Daemon atsign")
        _ = parser.add_argument(
            "socket_rendezvous_atsign", help="Socket rendezvous atsign"
        )

        _ = parser.add_argument(
            "-r",
            "--at-directory-host",
            default="root.atsign.org",
            help="atDirectory (aka root) host",
        )

        _ = parser.add_argument(
            "-t",
            "--tests-to-run",
            help="Space-separated list of test scripts to run",
            nargs="+",
        )

        _ = parser.add_argument(
            "-s",
            "--daemon-versions",
            help="Daemon versions to test",
            default=["d:4.0.5", "d:5.2.0", "d:5.5.0", "d:current", "c:current"],
        )

        _ = parser.add_argument(
            "-c",
            "--client-versions",
            help="Client versions to test",
            default=["d:4.0.5", "d:5.2.0", "d:5.5.0", "d:current"],
        )

        _ = parser.add_argument(
            "-rv",
            "--relay-versions",
            help="Relay versions to test",
            default=["d:4.0.5", "d:5.2.0", "d:5.5.0", "d:current"],
        )

        _ = parser.add_argument("-u", "--remote-username", help="Remote username")

        _ = parser.add_argument(
            "-w",
            "--daemon-start-wait",
            type=int,
            default=30,
            help="How long to wait for daemons to start up",
        )

        _ = parser.add_argument(
            "-N",
            "--concurrency",
            type=int,
            default=5,
            help="How many concurrent tests to run",
        )

        _ = parser.add_argument(
            "-n",
            "--no-recompile",
            action="store_true",
            help="Do not recompile binaries for current commit",
        )

        parsed = parser.parse_args(args=args)

        # Store all arguments as instance variables
        self.client_atsign = cast(str, parsed.client_atsign)
        self.daemon_atsign = cast(str, parsed.daemon_atsign)
        self.socket_rendezvous_atsign = cast(str, parsed.socket_rendezvous_atsign)
        self.at_directory_host = cast(str, parsed.at_directory_host)

        parsed.tests_to_run = cast(list[str], parsed.tests_to_run)
        self.tests_to_run = parsed.tests_to_run if parsed.tests_to_run else []

        parsed.daemon_versions = cast(list[str], parsed.daemon_versions)
        for version in parsed.daemon_versions:
            self.daemon_versions.append(Version(version))

        parsed.client_versions = cast(list[str], parsed.client_versions)
        for version in parsed.client_versions:
            self.client_versions.append(Version(version))

        parsed.relay_versions = cast(list[str], parsed.relay_versions)
        for version in parsed.relay_versions:
            self.relay_versions.append(Version(version))

        self.remote_username = cast(str, parsed.remote_username)
        self.daemon_start_wait = cast(int, parsed.daemon_start_wait)
        self.max_concurrency = cast(int, parsed.concurrency)
        self.allow_parallelization = cast(bool, parsed.allow_parallelization)
        self.recompile = not cast(bool, parsed.no_recompile)
