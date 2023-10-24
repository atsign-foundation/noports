import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFFF05E3E);
// const kBackGroundColorDark = Color(0xFF242424);
const kBackGroundColorDark = Color(0xFF222222);
const kProfileBarColor = Color(0xff3a3a3a);
const kProfileFormCardColor = Color(0xff262626);
const kProfileFormFieldColor = Color(0xff303030);

const kEmptyFieldValidationError = 'Field cannot be left blank';
const kAtsignFieldValidationError = 'Field must start with @';
const kProfileNameFieldValidationError = 'Field must only use alphanumeric characters and spaces';

const String dotEnvMimeType = 'text/plain';
const XTypeGroup dotEnvTypeGroup = XTypeGroup(
  label: 'dotenv',
  extensions: ['env'],
  mimeTypes: [dotEnvMimeType],
  uniformTypeIdentifiers: ['com.atsign.sshnp-config'],
);
const String dotPubMimeType = 'application/x-pem-file';
const XTypeGroup dotPubTypeGroup = XTypeGroup(
  label: 'dotpub',
  extensions: ['.pub'],
  mimeTypes: [dotEnvMimeType],
  uniformTypeIdentifiers: ['com.atsign.pubkey'],
);
