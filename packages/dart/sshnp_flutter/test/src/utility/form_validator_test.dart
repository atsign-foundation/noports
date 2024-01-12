import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/form_validator.dart';

void main() {
  group(
    FormValidator,
    () {
      test(
        '''
      Given empty string
      When validateRequiredField is called
      Then return kEmptyFieldValidationError''',
        () {
          expect(FormValidator.validateRequiredField(''),
              kEmptyFieldValidationError);
        },
      );
      test(
        '''
      Given test
      When validateRequiredField is called
      Then return null
      ''',
        () {
          expect(FormValidator.validateRequiredField('test'), null);
        },
      );

      test(
        '''
      Given empty string
      When validateAtsignField is called
      Then return kEmptyFieldValidationError
      ''',
        () {
          expect(FormValidator.validateAtsignField(''),
              kEmptyFieldValidationError);
        },
      );
      test(
        '''
      Given alice
      When validateAtsignField is called
      Then return kAtsignFieldValidationError
      ''',
        () {
          expect(FormValidator.validateAtsignField('alice'),
              kAtsignFieldValidationError);
        },
      );
      test(
        '''
      Given @alice
      When validateAtsignField is called
      Then return null
      ''',
        () {
          expect(FormValidator.validateAtsignField('@alice'), null);
        },
      );
    },
  );
}
