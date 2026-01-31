import 'dart:typed_data';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_contact/at_contact.dart';

/// Replacement for at_contacts_flutter's ContactService
/// This provides the same core functionality without the problematic plugin
class ContactService {
  static final ContactService _instance = ContactService._();
  factory ContactService() => _instance;
  ContactService._();

  late AtContactsImpl _atContactImpl;
  late AtClientManager _atClientManager;
  bool _isInitialized = false;

  /// Initialize the contact service
  void init() {
    if (_isInitialized) return;
    _atClientManager = AtClientManager.getInstance();
    final currentAtsign = _atClientManager.atClient.getCurrentAtSign();
    if (currentAtsign != null) {
      _atContactImpl = AtContactsImpl(_atClientManager.atClient, currentAtsign);
      _isInitialized = true;
    }
  }

  /// Fetch all contacts
  Future<List<AtContact>?> fetchContacts() async {
    init();
    try {
      return await _atContactImpl.listContacts();
    } catch (e) {
      return null;
    }
  }

  /// Get contact details
  Future<Map<String, dynamic>> getContactDetails(
    String? atSign,
    dynamic image,
  ) async {
    init();
    Map<String, dynamic> contactDetails = {};

    if (atSign == null) return contactDetails;

    try {
      final contact = await _atContactImpl.get(atSign);
      if (contact != null) {
        contactDetails['atSign'] = contact.atSign;
        contactDetails['tags'] = contact.tags;

        // Try to get image if available
        if (contact.tags != null && contact.tags!.containsKey('image')) {
          contactDetails['image'] = contact.tags!['image'] as Uint8List?;
        }
      }
    } catch (e) {
      // Return empty map on error
    }

    return contactDetails;
  }

  /// Add a new atSign to contacts
  Future<bool> addAtSign({required String atSign, String? nickName}) async {
    init();
    try {
      final contact = AtContact(atSign: atSign);
      if (nickName != null && nickName.isNotEmpty) {
        contact.tags = {'nickname': nickName};
      }
      await _atContactImpl.add(contact);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete an atSign from contacts
  Future<bool> deleteAtSign({required String atSign}) async {
    init();
    try {
      await _atContactImpl.delete(atSign);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark/unmark a contact as favorite
  Future<bool> markFavContact(AtContact contact) async {
    init();
    try {
      contact.favourite = !(contact.favourite ?? false);
      await _atContactImpl.update(contact);
      return true;
    } catch (e) {
      return false;
    }
  }
}
