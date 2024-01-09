class PackageSource:
    pass


class LocalPackageSource(PackageSource):
    def __init__(self, path: str):
        self.path = path


class GitPackageSource(PackageSource):
    def __init__(self, url: str, ref: str = "trunk"):
        self.url = url
        self.ref = ref


class ReleasePackageSource(PackageSource):
    def __init__(self, version: str):
        if not version.startswith("v"):
            version = f"v{version}"
        self.version = version


class ArchivePackageSource(PackageSource):
    def __init__(self, path: str):
        self.path = path
