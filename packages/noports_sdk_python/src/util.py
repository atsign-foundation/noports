def norm_atsign(atsign: str) -> str:
    """
    Returns the normalized version of an atsign.
    """
    return "@" + (atsign.strip().lstrip("@").lower())


def filter_none(l: list) -> list:
    """
    Returns a list with all None values removed.
    """
    return [i for i in l if i is not None]
