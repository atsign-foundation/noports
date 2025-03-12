# ABC = Abstract Base Class
from abc import ABC
from enum import Enum
from typing import Self
from lib.version import VersionConstraint, Version
from lib.test_step import TestStep, TestStepParams, TestStepStatus


class TestStatus(Enum):
    PASS = 0
    FAIL = 1
    IN_PROGRESS = 2
    SKIP = 50


class TestResult:
    status: TestStatus
    logs: list[str]

    def __init__(
        self, status: TestStatus = TestStatus.IN_PROGRESS, logs: list[str] | None = None
    ):
        self.status = status
        if not logs:
            logs = []
        self.logs = logs

    def success(self) -> Self:
        self.status = TestStatus.PASS
        return self

    def skip(self) -> Self:
        self.status = TestStatus.SKIP
        return self

    def fail(self) -> Self:
        self.status = TestStatus.FAIL
        return self


class Test(ABC):
    # Only run the test against valid constraints
    client_constraints: tuple[str, VersionConstraint]
    daemon_constraints: tuple[str, VersionConstraint]
    relay_constraints: tuple[str, VersionConstraint]
    steps: list[TestStep]

    def should_run_test(
        self, client_version: Version, daemon_version: Version, relay_version: Version
    ) -> bool:
        return (
            client_version.compare(*self.client_constraints)
            and daemon_version.compare(*self.daemon_constraints)
            and relay_version.compare(*self.relay_constraints)
        )

    def run_test(
        self,
        client_version: Version,
        daemon_version: Version,
        relay_version: Version,
        step_params: list[TestStepParams],
    ) -> TestResult:
        result = TestResult()
        if not self.should_run_test(
            client_version=client_version,
            daemon_version=daemon_version,
            relay_version=relay_version,
        ):
            return result.skip()

        for index, step in enumerate(self.steps):
            step_result = step.run(step_params[index])
            result.logs.extend(step_result.logs)
            if step_result.status == TestStepStatus.FAIL:
                return result.fail()

        return result.success()
