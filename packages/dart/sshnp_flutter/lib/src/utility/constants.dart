import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFFF05E3E);
const kBackGroundColorDark = Color(0xFF222222);
const kDarkBarColor = Color(0xFF1E1E1E);
const kProfileBarColor = Color(0xff3a3a3a);
const kProfileBackgroundColor = Color(0xff262626);
const kProfileFormFieldColor = Color(0xff303030);
const kTextColorDark = Color(0xffB3B3B3);
const kIconColorDark = Color(0xff585858);
const kIconColorBackground = Color(0xffDCDCDC);
const kIconColorBackgroundDark = Color(0xff888888);
const kListTileColor = Color(0x70bcbcbc);
const kListTileTitleColorDark = Color(0xff252525);
const kSSHKeyManagementCardColor = Color(0xff3e3e3e);
const kSshKeyManagementBarColor = Color(0xff505050);
const kPrivateKeyGridBackgroundColor = Color(0xff3F3F3F);
const kInputChipBackgroundColor = Color(0XFF515151);
const kHomeScreenGreyText = Color(0xffB7B7B7);

const kEmptyFieldValidationError = 'Field cannot be left blank';
const kAtsignFieldValidationError = 'Field must start with @';
const kProfileNameFieldValidationError = 'Field must only use lower case alphanumeric characters and spaces';
const kPrivateKeyFieldValidationError = 'Field must only use lower case alphanumeric characters';
const kIntFieldValidationError = 'Field must only use numbers';
const kPortFieldValidationError = 'Field must use a valid port number';
const kPrivateKeyDropDownOption = 'Create a new private key';

const String dotEnvMimeType = 'text/plain';
const XTypeGroup dotEnvTypeGroup = XTypeGroup(
  label: 'dotenv',
  extensions: ['env'],
  mimeTypes: [dotEnvMimeType],
  uniformTypeIdentifiers: ['com.atsign.sshnp-config'],
);
const String dotPrivateMimeType = 'application/x-pem-file';
const XTypeGroup dotPrivateTypeGroup = XTypeGroup(
  label: 'sshPrivateKey',
);

// Form Field Constants
const kFieldDefaultWidth = 192.0;
const kFieldDefaultHeight = 33.0;

// Device Size

const kSmallDeviceMinSize = 0;
const kSmallDeviceMaxSize = 599;
const kMediumDeviceMinSize = 600;
const kMediumDeviceMaxSize = 839;
const kLargeDeviceMinSize = 840;
const kLargeDeviceMaxSize = 1439;
const kExtraLargeDeviceMinSize = 1440;
