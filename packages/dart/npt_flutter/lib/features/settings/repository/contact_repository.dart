// 🎯 Dart imports:
import 'dart:async';
import 'dart:typed_data';

import 'package:at_client/at_client.dart';
import 'package:at_contact/at_contact.dart';
import 'package:at_contacts_flutter/services/contact_service.dart';
import 'package:at_utils/at_utils.dart';

import '../../../util/constants.dart';

/// A singleton that makes all the network calls to the @platform.
class ContactsService {
  static final ContactsService _singleton = ContactsService._internal();
  ContactsService._internal();

  factory ContactsService.getInstance() {
    return _singleton;
  }
  final AtSignLogger _logger = AtSignLogger(Constants.namespace);

  AtClient? atClient;
  var atClientManager = AtClientManager.getInstance();
  static var atContactService = ContactService();

  /// Fetch the current atsign contacts.
  Future<List<AtContact>?> getContactList() {
    return atContactService.fetchContacts();
  }

  /// Fetch the current atsign profile image
  Future<Uint8List?> getCurrentAtsignProfileImage() async {
    return atContactService
        .getContactDetails(atClientManager.atClient.getCurrentAtSign(), null)
        .then((value) {
          return value['image'];
        });
  }

  /// Fetch details for the current atsign
  Future<Map<String, dynamic>> getCurrentAtsignContactDetails() {
    return atContactService.getContactDetails(
      atClientManager.atClient.getCurrentAtSign(),
      null,
    );
  }

  /// Delete contact from contact list.
  Future<bool> addContact(Atsign atsign, String? nickname) async {
    try {
      bool isAdded = await atContactService.addAtSign(
        atSign: atsign,
        nickName: nickname,
      );

      return isAdded;
    } on AtClientException catch (atClientExcep) {
      _logger.severe('❌ AtClientException : ${atClientExcep.message}');
      return false;
    } catch (e) {
      _logger.severe('❌ Exception : ${e.toString()}');
      return false;
    }
  }

  /// Delete contact from contact list.
  Future<bool> deleteContact(Atsign atsign) async {
    try {
      bool isDeleted = await atContactService.deleteAtSign(atSign: atsign);

      return isDeleted;
    } on AtClientException catch (atClientExcep) {
      _logger.severe('❌ AtClientException : ${atClientExcep.message}');
      return false;
    } catch (e) {
      _logger.severe('❌ Exception : ${e.toString()}');
      return false;
    }
  }

  /// Add/remove contact as favorite.
  Future<bool> markUnmarkFavoriteContact(AtContact contact) async {
    try {
      bool isMarked = await atContactService.markFavContact(contact);

      return isMarked;
    } on AtClientException catch (atClientExcep) {
      _logger.severe('❌ AtClientException : ${atClientExcep.message}');
      return false;
    } catch (e) {
      _logger.severe('❌ Exception : ${e.toString()}');
      return false;
    }
  }
}
