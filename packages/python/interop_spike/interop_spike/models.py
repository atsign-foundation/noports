from dataclasses import dataclass
from enum import Enum


class AtsignRvd(Enum):
    """Description of AtsignRvd"""
    AMERICAS = "@rv_am"
    ASIAPACIFIC = "@rv_ap"
    EUROPE = "@rv_eu"

@dataclass
class NPClientArgs:
    """Description of NPClientArgs"""
    atsign: str
    device_atsign: str
    device_name: str
    srvd: AtsignRvd
    local_port: int
    remote_port: int 
    remote_host: str = "localhost"

    def __str__(self):
        return (f"-f {self.atsign} -t {self.device_atsign} -d {self.device_name} "
                f"-r {self.srvd.value} -l {self.local_port} "
                f"-h {self.remote_host} -p {self.remote_port}")
    
@dataclass
class NPServerArgs:
    """Description of NPServerArgs"""
    atsign: str
    manager_atsign: str
    device_name: str
    policy: str | None = None

    def __str__(self):
        return f"-a {self.atsign} -m {self.manager_atsign} {f'-p {self.policy}' if self.policy else ''} -d {self.device_name}"
    
class BinaryName(Enum):
    SSHNPD = "sshnpd"
    SSHNP = "sshnp"
    NPT = "npt"
    SRV = "srv"
    SRVD = "srvd"
    
@dataclass
class BinaryRequest:
    """Description of BinaryRequest"""
    name: BinaryName
    args: str