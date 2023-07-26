def norm_atsign(atsign: str) -> str:
    """
    Returns the normalized version of an atsign.
    """
    return "@" + (atsign.strip().lstrip("@").lower())
