final cramRegex = r'(?<atsign>.+):cram:(?<secret>.+)$';
final enrollRegex =
    r'^(?<atsign>@[^:]+):enroll:otp:(?<otp>[A-Za-z0-9]{6})' // base pattern
    r'(?:\[:name:(?<device_name>[^:\]]+))?' // optional :name:
    r'(?:[:]?keyfile:(?<keyfile_path>[^\]]+))?\]?$'; // optional :keyfile:
final issueKeysRegex = r'(?<atsign>)';
