# ABC = Abstract Base Class
from abc import ABC, abstractmethod
from enum import Enum
from typing import Any


type TestStepParams = dict[str, Any]


class TestStepStatus(Enum):
    PASS = 0
    FAIL = 1


class TestStepResult:
    status: TestStepStatus
    logs: list[str] = []

    def __init__(self, status: TestStepStatus, logs: list[str] | None):
        self.status = status
        if logs:
            self.logs = logs


class TestStep(ABC):
    @abstractmethod
    def run(self, params: TestStepParams | None) -> TestStepResult:
        pass
