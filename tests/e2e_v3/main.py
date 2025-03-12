from collections.abc import Sequence
from lib.config import Config


def main(args: Sequence[str] | None = None) -> int:
    config = Config(args)
    return 0


if __name__ == "__main__":
    main()
