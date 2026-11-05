import 'dart:io';

import 'package:at_client_cli/at_client_cli.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/npp.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnoports/src/create_at_client_cli.dart';
import 'package:sshnoports/src/print_version.dart';
import 'package:sshnoports/src/version.dart' as binaries_version;
import 'package:path/path.dart' as path;


late AtSignLogger logger;

const String _description =
    'NoPorts policy service: makes authorization decisions for NoPorts'
    ' daemons which delegate access control to a policy atSign.';

Future<void> main(List<String> args) async {
  // 1. Parse if --help or --version was called
  try {
    if(NPPParams.argParser.parse(args)['help']) {
      stdout.write(formatCliHelp(
          description: _description, optionsUsage: NPPParams.argParser.usage));
      exit(0);
    }
    if(NPPParams.argParser.parse(args)['version']) {
      printVersion();
      exit(0);
    }
  } on ArgumentError catch (e) {
    stderr.write(formatCliHelp(
        description: _description, optionsUsage: NPPParams.argParser.usage));
    stderr.writeln(e.message);
    exit(1);
  } on FormatException catch (e) {
    stderr.write(formatCliHelp(
        description: _description, optionsUsage: NPPParams.argParser.usage));
    stderr.writeln(e.message);
    exit(1);
  } catch (err) {
    stderr.write(formatCliHelp(
        description: _description, optionsUsage: NPPParams.argParser.usage));
    stderr.writeln(err);
    exit(1);
  }

  // 2. Parse args
  final NPPParams nppParams;
  try {
    nppParams = NPPParams.fromArgs(args);
  } catch (err) {
    stderr.write(formatCliHelp(
        description: _description, optionsUsage: NPPParams.argParser.usage));
    stderr.writeln(err);
    exit(1);
  }

  // 3. Process args
  // 3a. --persistence-method
  final validPersistenceMethods = ['atserver', 'file', 'none']; // make these a const TODO
  if(!validPersistenceMethods.contains(nppParams.persistenceMethod)) {
    stderr.writeln('Invalid persistence-method: ${nppParams.persistenceMethod}');
    stderr.writeln('Valid options are: ${validPersistenceMethods.join(', ')}');
    exit(1);
  }

  // 3b. --key-file
  final File atKeysFile = File(nppParams.atKeysFilePath);
  if(!(await atKeysFile.exists())) {
    stderr.writeln('\n Unable to find .atKeys file : ${nppParams.atKeysFilePath}');
    exit(1);
  }

  // 3c. --verbose
  if(nppParams.verbose) {
    AtSignLogger.root_level = 'INFO';
  } else {
    AtSignLogger.root_level = 'SHOUT';
  }
  AtSignLogger.defaultLoggingHandler = StdErrLoggingHandler();
  logger = AtSignLogger('npp');

  // 3d. Sanitize managerAllowList
  final Set<String> managerAllowList;
  if(nppParams.managerAllowList.trim().isEmpty) {
    managerAllowList = <String>{};
  } else {
    managerAllowList = nppParams.managerAllowList
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  }

  // 3e. --event-logging-atsign
  if (nppParams.eventLoggingAtSign != null) {
    try {
      nppParams.eventLoggingAtSign!.toAtsign();
    } on InvalidAtSignException catch (e) {
      stderr.writeln('Invalid --event-logging-atsign: ${e.message}');
      exit(1);
    }
  }


  // 4. Set up AtClient instance
  final AtClient atClient;
  try {
    atClient = await createAtClientCli(
      atsign: nppParams.atSign,
      atKeysFilePath: nppParams.atKeysFilePath,
      rootDomain: nppParams.rootDomain,
      atServiceFactory: ServiceFactoryWithNoOpSyncService(),
      namespace: nppParams.baseNamespace,
      storagePath: nppParams.storagePath,
    );
  } catch (err) {
    stderr.writeln(err);
    exit(1);
  }

  // 5. Set up NppService
  // 5a. Set up NppCache and NppOperationHooks
  final NppCache nppCache;
  NppOperationHooks? nppOperationHooks;
  switch(nppParams.persistenceMethod) {
    case 'atserver': {
      logger.info('Using persistence method: "atserver"');
      nppCache = await nppCacheFromAtServer(
        atClient: atClient,
        baseNamespace: nppParams.baseNamespace,
        domainNamespace: nppParams.domainNamespace,
      );

      nppOperationHooks = nppOperationHooksForAtServer(
        atClient: atClient,
        baseNamespace: nppParams.baseNamespace,
        domainNamespace: nppParams.domainNamespace,
      );
      logger.info('Successfully loaded policy cache from atServer');
      break;
    }
    case 'file': {
      logger.info('Using persistence method: "file"');
      Directory policyDirectory;
      if(nppParams.policyDirectory == null) {
        policyDirectory = getDefaultPolicyDirectoryPath(
          baseDir: getHomeDirectory(),
          atSign: nppParams.atSign);
      } else {
        policyDirectory = Directory(nppParams.policyDirectory!);
      }

      if(!await policyDirectory.exists()) {
        logger.info('Policy directory does not exist. Creating: ${policyDirectory.path}');
        await policyDirectory.create(recursive: true);
        logger.info('Successfully created policy directory: ${policyDirectory.path}');
      }

      nppCache = await nppCacheFromFiles(
        policyDirectory: policyDirectory,
      );
      nppOperationHooks = nppOperationHooksForFiles(
        policyDirectory: policyDirectory,
      );
      logger.info('Successfully loaded policy cache from files in ${policyDirectory.path}');
    }
    case 'none': {
      logger.info('Using persistence method: "none". Instantiating empty NppCache');
      nppCache = NppCache();
    }
    default: {
      stderr.writeln('${nppParams.persistenceMethod} is not a valid type');
      exit(1);
    }
  }

  // 5b. Create NppService
  final NppService nppService = NppService(
    atClient: atClient,
    managerAllowList: managerAllowList,
    nppCache: nppCache,
    nppOperationHooks: nppOperationHooks,
    binariesVersion: binaries_version.packageVersion,
    eventLoggingAtSign: nppParams.eventLoggingAtSign,
    persistenceMethod: nppParams.persistenceMethod,
  );
  nppService.init();
  try {
    await nppService.start();
  } on EventLoggingConfigException catch (e) {
    stderr.writeln(e);
    exit(1);
  }

  // 6. On SIGINT, and SIGTERM where Dart can watch it, tell the event logging
  // Atsign npp is stopping, and wait for that to reach our atServer, before
  // exiting. A second signal exits at once, since stop() does nothing twice.
  Future<void> stopAndExit(ProcessSignal signal) async {
    await nppService.stop(reason: signal.toString());
    exit(1);
  }

  ProcessSignal.sigint.watch().listen(stopAndExit);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(stopAndExit);
  }
}

Directory getDefaultPolicyDirectoryPath({
  required final String atSign,
  String? baseDir,
}) {
  if(baseDir == null) {
    String? homeDirectory = getHomeDirectory();
    if(homeDirectory == null) {
      stderr.writeln('homeDirectory could not be resolved');
      exit(1);
    }
    baseDir = homeDirectory;
  }

  // append /.atsign/npp/<atsign>
  return Directory(path.normalize(
    '$baseDir'
    '/.atsign'
    '/npp'
    '/$atSign').replaceAll('/', Platform.pathSeparator));
}

