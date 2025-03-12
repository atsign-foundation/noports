# Minimum python 3.12, script using python 3.12+ syntax

from re import match
from typing import override

type VersionConstraint = Version | str | dict[str, VersionConstraint]


class Version:
    tag: str
    major: int
    minor: int
    patch: int
    current: bool = False
    any: bool = False

    def __init__(self, version: str):
        pattern = r"([cd]):(current|any)"
        matched = match(pattern, version)
        if matched:
            # Pick ridiculously high numbers for "current" as it will always be
            # considered latest
            self.tag, word = matched.groups()
            self.major = 999
            self.minor = 999
            self.patch = 999
            if word == "current":
                self.current = True
            elif word == "any":
                self.any = True
            return
        pattern = r"(.*):(\d+)\.(\d+)\.(\d+)"
        matched = match(pattern, version)
        if not matched:
            raise ValueError(f"Invalid version format: {version}")
        self.tag, major, minor, patch = matched.groups()
        self.major = int(major)
        self.minor = int(minor)
        self.patch = int(patch)

    @override
    def __str__(self):
        if self.current:
            return f"{self.tag}:current"
        return f"{self.tag}:{self.major}.{self.minor}.{self.patch}"

    # TODO handle "current"
    def compare(self, operator: str, expr: VersionConstraint) -> bool:
        # operators
        OR = "OR"
        AND = "AND"
        GTE = ">="
        LTE = "<="
        GT = ">"
        LT = "<"
        EQ = "=="
        NE = "!="
        PB = "^"  # "Patch bump"

        # Handle && and ||
        if operator == AND or operator == OR:
            if type(expr) is not dict:
                raise TypeError(f"{operator} version expression must be a dict type")

            if operator == AND:
                for op, ex in expr.items():
                    if not self.compare(op, ex):
                        return False
                return True

            if operator == OR:
                for op, ex in expr.items():
                    if self.compare(op, ex):
                        return True
                return False

        # Otherwise ensure that type of expr is Version
        else:
            if type(expr) is str:
                expr = Version(expr)
            elif type(expr) is not Version:
                raise TypeError(
                    f"{operator} version expression must be a Version or str type"
                )

        if operator == GTE:
            # e.g. compare("d:5.0.0", "==", "d:any") -> True
            if self.tag == expr.tag and expr.any:
                return True
            return (
                self.tag == expr.tag
                and self.major >= expr.major
                and self.minor >= expr.minor
                and expr.patch >= expr.patch
            )

        if operator == LTE:
            return (
                self.tag == expr.tag
                and self.major <= expr.major
                and self.minor <= expr.minor
                and expr.patch <= expr.patch
            )

        if operator == GT:
            if self.tag != expr.tag:
                return False
            if self.major > expr.major:
                return True
            if self.major < expr.major:
                return False
            if self.minor > expr.minor:
                return True
            if self.minor < expr.minor:
                return False
            if self.patch > expr.patch:
                return True
            if self.patch < expr.patch:
                return False
            return False

        if operator == LT:
            if self.tag != expr.tag:
                return False
            if self.major < expr.major:
                return True
            if self.major > expr.major:
                return False
            if self.minor < expr.minor:
                return True
            if self.minor > expr.minor:
                return False
            if self.patch < expr.patch:
                return True
            if self.patch > expr.patch:
                return False
            return False

        if operator == EQ:
            return (
                self.tag == expr.tag
                and self.major == expr.major
                and self.minor == expr.minor
                and expr.patch == expr.patch
            )

        if operator == NE:
            return (
                self.tag != expr.tag
                and self.major != expr.major
                and self.minor != expr.minor
                and expr.patch != expr.patch
            )

        if operator == PB:
            return (
                self.tag == expr.tag
                and self.major == expr.major
                and self.minor == expr.minor
                and self.patch >= expr.patch
            )

        raise ValueError(f"Unknown operator: {operator}")
