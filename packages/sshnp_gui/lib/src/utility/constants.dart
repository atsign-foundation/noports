import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFFF05E3E);
// const kBackGroundColorDark = Color(0xFF242424);
const kBackGroundColorDark = Color(0xFF222222);
const kProfileBarColor = Color(0xff3a3a3a);
const kProfileFormCardColor = Color(0xff262626);
const kProfileFormFieldColor = Color(0xff303030);
const kTextColorDark = Color(0xffB3B3B3);
const kIconColorDark = Color(0xff585858);
const kIconColorBackground = Color(0xffDCDCDC);
const kIconColorBackgroundDark = Color(0xff888888);
const kListTileColor = Color(0x70bcbcbc);
const kSSHKeyManagementCardColor = Color(0xff3e3e3e);
const kSshKeyManagementBarColor = Color(0xff505050);

const kEmptyFieldValidationError = 'Field cannot be left blank';
const kAtsignFieldValidationError = 'Field must start with @';
const kProfileNameFieldValidationError = 'Field must only use alphanumeric characters and spaces';
const kPrivateKeyFieldValidationError = 'Field must be a valid private key';

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
  // mimeTypes: [dotPrivateMimeType],
  // extensions: ['pem', ''],
);

// Form Field Constants
const kFieldDefaultWidth = 192.0;
const kFieldDefaultHeight = 33.0;
