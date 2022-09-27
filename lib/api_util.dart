import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_lookup/at_lookup.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

class ApiUtil {
  late IOClient _http;
  late String _authority;

  factory ApiUtil() {
    return ApiUtil._internal();
  }

  ApiUtil._internal() {
    HttpClient ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    _http = IOClient(ioc);
    _authority = Constants.hostProduction;
  }

  /// Returns a Future<List<String>> containing available atSigns.
  Future<List<String>> getFreeAtSigns(int amount) async {
    List<String> atSigns = <String>[];
    Response response;
    for (int i = 0; i < amount; i++) {
      // get request at my.atsign.com/api/app/v3/get-free-atsign/
      response = await getRequest(_authority, Constants.pathGetFreeAtSign);
      String atSign = jsonDecode(response.body)['data']['atsign'];
      atSigns.add(atSign);
    }
    return atSigns;
  }

  /// Returns true if the request to send the OTP was successful.
  /// Sends an OTP to the `email` provided.
  /// registerAtSignValidate should be called after calling this method.
  Future<bool> registerAtSign(String atSign, String email,
      {oldEmail}) async {
    Response response = await postRequest(_authority, Constants.pathRegisterAtSign, {
      'atsign': atSign,
      'email': email,
      'oldEmail': oldEmail,
    });

    Map<String, dynamic> jsonDecoded = jsonDecode(response.body);
    bool sentSuccessfully = jsonDecoded['message'].toLowerCase().contains('success');
    return sentSuccessfully;
  }

  /// Returns the cram key if the OTP was valid. Null if the cram key could not be obtained.
  /// Validates the OTP sent to the `email` provided.
  /// registerAtSign should be called before calling this method.
  /// The `atSign` provided should be an atSign from the list returned by `getFreeAtSigns`.
  /// oldEmail is to support old atSign accounts I think TODO check
  /// confirmation is defaulted to false. If set to true, you are requesting for the cram key of the atSign that was previously validated. (AKA you are calling this method for the second time.) 
  Future<String?> registerAtSignValidate(
      String atSign, String email, String otp,
      {oldEmail, confirmation}) async {
    Response response = await postRequest(_authority, Constants.pathRegisterAtSignValidate, {
      'atsign': atSign,
      'email': email,
      'otp': otp,
      'oldEmail': oldEmail,
      'confirmation': 'true',
    });
    String? cramKey;
    Map<String, dynamic> jsonDecoded = jsonDecode(response.body);
    if((jsonDecoded['message'] != null && (jsonDecoded['message'] as String).toLowerCase().contains('verified')) && jsonDecoded['cramkey'] != null) {
      // this is the email's first atSign, get the cram key.
      cramKey = (jsonDecoded['cramkey'] as String).split(":")[1];
    }
    return cramKey;
  }

  /// Authenticate an atSign that is already associated with an email
  /// Running this method will send the OTP to the email that is associated with `atSign`
  /// authenticateAtSignValidate should be called after this method.
  /// Will return true if the OTP was successfully sent.
  Future<bool> authenticateAtSign(String atSign) async {
    Response response = await postRequest(_authority, Constants.pathAuthenticateAtSign, {'atsign': atSign});

    Map<String, dynamic> jsonDecoded = jsonDecode(response.body);
    String? message = jsonDecoded['message'];
    return (message != null && message.contains("Sent Successfully"));
  }

  /// Returns a Future<Response> containing the response from the server.
  /// Provide the `otp` sent to the `email` provided.
  /// authenticateAtSign should be called before calling this method to send the OTP.
  /// The `atSign` provided should be an atSign that is already associated with an email.
  /// Upon successful otp validation, the cram key will be returned.
  /// If unsuccessful, return String? will be null.
  Future<String?> authenticateAtSignValidate(String atSign, String otp) async {
    Response response = await postRequest(_authority, Constants.pathAuthenticateAtSignValidate, {'atsign': atSign, 'otp': otp});
    Map<String, dynamic> jsonDecoded = jsonDecode(response.body);
    String? message = jsonDecoded['message'];
    String? cramkey;
    if (message != null && message.toLowerCase().contains('verified')) {
      cramkey = jsonDecoded['cramkey']!.split(":")[1];
    }
    return cramkey;
  }

  /// generic GET request
  Future<Response> getRequest(String authority, String path) async {
    Uri uri = Uri.https(authority, path);

    Response response = await _http.get(
      uri,
      headers: <String, String>{
        'Authorization': Constants.authorization,
        'Content-Type': Constants.contentType,
      },
    );
    // print('getResponse: ${response.body}');
    return response;
  }

  /// generic POST request
  Future<Response> postRequest(String authority, String path, Map<String, String?> data) async {
    Uri uri = Uri.https(authority, path);

    String body = json.encode(data);
    Response response = await _http.post(
      uri,
      body: body,
      headers: <String, String>{
        'Authorization': Constants.authorization,
        'Content-Type': Constants.contentType,
      },
    );

    // print('postRequest: ${response.body}');
    return response;
  }

  /// Hot fix in case activating the atSign takes too long (if the person does not press the orange "Activate" button on their atSign, then the secondary was not initialized just yet. Just run this method with async/await and it will pause your code until the secondary is successfully initialized.)
  Future<void> runUntilSecondaryExists(String rootUrl, String atSign, {timeoutIterations = 10000000}) async {
  List<String> s = rootUrl.split(':');
    String rootDomain = s[0];
    int rootPort = int.parse(s[1]);
    late SecondaryAddress sAddress;
    bool exists = false;
    int timeout = timeoutIterations;
    int count = 0;
    do {
      count++;
      try {
        sAddress = await CacheableSecondaryAddressFinder(rootDomain, rootPort).findSecondary(atSign);
        exists = true;
      } catch (e) {
        // ignore
      }

    } while(!exists && count < timeout); 
    if(sAddress.host.length > 2) {
      print('Secondary address found! ${sAddress.host}:${sAddress.port} | Iterations: $count/$timeout');
    } else {
      print('Secondary address not found after $count/$timeout iterations');
    }
    throw Exception('Secondary address not found after $count/$timeout iterations');
  }
}

class Constants {
  /// Authorities
  static const String hostProduction = 'my.atsign.com';
  static const String hostStaging = 'my.atsign.wtf';

  /// API Paths
  static const String pathGetFreeAtSign = '/api/app/v3/get-free-atsign/';
  static const String pathRegisterAtSign = '/api/app/v3/register-person/';
  static const String pathRegisterAtSignValidate =
      '/api/app/v3/validate-person/';
  static const String pathAuthenticateAtSign =
      '/api/app/v3/authenticate/atsign';
  static const String pathAuthenticateAtSignValidate =
      '/api/app/v3/authenticate/atsign/activate';

  /// API headers
  static const String contentType = 'application/json';
  static const String authorization = '477b-876u-bcez-c42z-6a3d';
}
