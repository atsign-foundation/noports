import 'dart:async';
import 'dart:io';

import 'package:at_client_cli/at_client_cli.dart';
import 'package:path/path.dart' as path;

const String _primingNamespace = 'npe2e_prime';
const Duration _primingRecordTtl = Duration(minutes: 1);
const Duration _primingStepTimeout = Duration(seconds: 30);

typedef SharedKeyPair = ({String sharer, String receiver});

/// Every ordered pair of distinct atSigns in [atsigns], canonicalised and
/// deduplicated, grouped by sharer in the order the atSigns first appear.
List<SharedKeyPair> sharedKeyPairs(Iterable<String> atsigns) {
  final List<String> distinct = {
    for (final String atsign in atsigns) atsign.toAtsign(),
  }.toList();
  return [
    for (final String sharer in distinct)
      for (final String receiver in distinct)
        if (sharer != receiver) (sharer: sharer, receiver: receiver),
  ];
}

/// Creates the shared key from each of [atsigns] to each other one, one put
/// at a time, with each sharer's atKeys from `~/.atsign/keys`.
///
/// Throws, naming the sharer and receiver, when a put returns false, throws
/// or times out.
Future<void> primeSharedKeys({
  required final List<String> atsigns,
  required final String rootDomain,
  required final Directory storageDirectory,
}) async {
  final List<SharedKeyPair> pairs = sharedKeyPairs(atsigns);
  final Map<String, List<String>> receiversBySharer = {};
  for (final SharedKeyPair pair in pairs) {
    (receiversBySharer[pair.sharer] ??= []).add(pair.receiver);
  }
  print(
    'Priming ${pairs.length} shared key(s) among '
    '${receiversBySharer.length} atSign(s)...',
  );

  await storageDirectory.create(recursive: true);
  // NOTE a client that finds a shared key in its own storage writes none to
  // the atServer, so each call starts from empty storage.
  final Directory runStorage = await storageDirectory.createTemp(
    'shared_key_priming_',
  );

  for (final MapEntry(key: String sharer, value: List<String> receivers)
      in receiversBySharer.entries) {
    final AtClient client = await _openSharerClient(
      sharer: sharer,
      rootDomain: rootDomain,
      storageDirectory: Directory(path.join(runStorage.path, sharer)),
    );
    for (final String receiver in receivers) {
      await _putThrowawayRecord(
        client: client,
        sharer: sharer,
        receiver: receiver,
      );
      print('    $sharer -> $receiver');
    }
    await client.stop();
  }
  print('');
}

Future<AtClient> _openSharerClient({
  required final String sharer,
  required final String rootDomain,
  required final Directory storageDirectory,
}) async {
  final AtRootDomain parsedRootDomain = AtRootDomain.parse(rootDomain);
  final AtClientPreference preference = AtClientPreference()
    ..namespace = _primingNamespace
    ..fetchOfflineNotifications = false
    ..rootDomain = parsedRootDomain.rootDomain
    ..rootPort = parsedRootDomain.rootPort;
  final String keysFilePath = path.join(
    getHomeDirectory()!,
    '.atsign',
    'keys',
    '${sharer}_key.atKeys',
  );
  try {
    return await Atsign(sharer)
        .open(
          keys: FileAtKeysIo(filePath: (_) => keysFilePath, passPhrase: ''),
          preference: preference,
          storage: HiveAtClientStorage(
            atSign: sharer,
            storagePath: storageDirectory.path,
            closedByClient: true,
          ),
          lookUps: lookUpsFor(preference.rootDomain),
          secondaryAddressFinder: CacheableSecondaryAddressFinder(
            preference.rootDomain,
            preference.rootPort,
          ),
          serviceFactory: ServiceFactoryWithNoOpSyncService(),
        )
        .timeout(_primingStepTimeout);
  } catch (e) {
    throw Exception(
      'Priming shared keys: could not open a client for $sharer with '
      '$keysFilePath: $e',
    );
  }
}

Future<void> _putThrowawayRecord({
  required final AtClient client,
  required final String sharer,
  required final String receiver,
}) async {
  final AtKey atKey = AtKey()
    ..key = 'prime'
    ..namespace = _primingNamespace
    ..sharedBy = sharer
    ..sharedWith = receiver
    ..metadata = (Metadata()..ttl = _primingRecordTtl.inMilliseconds);
  final bool stored;
  try {
    stored = await client
        .put(
          atKey,
          'x',
          putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
        )
        .timeout(_primingStepTimeout);
  } catch (e) {
    throw Exception(
      'Priming the shared key from $sharer to $receiver failed: $e',
    );
  }
  if (!stored) {
    throw Exception(
      'Priming the shared key from $sharer to $receiver failed: the put '
      'returned false',
    );
  }
}
