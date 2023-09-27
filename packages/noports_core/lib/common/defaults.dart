import 'package:noports_core/sshrv/sshrv.dart';

const defaultVerbose = false;
const defaultRsa = false;
const defaultRootDomain = 'root.atsign.org';
const defaultSshrvGenerator = SSHRV.localBinary;
const defaultLocalSshdPort = 22;
const defaultRemoteSshdPort = 22;

/// value in seconds after which idle ssh tunnels will be closed
const defaultIdleTimeout = 15;
