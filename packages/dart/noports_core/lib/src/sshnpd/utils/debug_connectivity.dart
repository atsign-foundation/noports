import 'dart:io';
import 'package:at_lookup/at_lookup.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart debug_connectivity.dart <atsign>');
    exit(1);
  }
  
  final atSign = args[0];
  final rootDomain = 'root.atsign.org';
  final rootPort = 64;
  
  print('--------------------------------------------------');
  print('🔍 Connectivity Debugger for $atSign');
  print('--------------------------------------------------');
  
  // 1. Root Server Check
  print('\nStep 1: Connecting to Root Server ($rootDomain:$rootPort)...');
  try {
    final secondaryUrl = await AtLookupImpl.findSecondary(atSign, rootDomain, rootPort);
    if (secondaryUrl == null) {
      print('❌ Error: Could not find secondary URL for $atSign');
      exit(1);
    }
    print('✅ Success! Root Server says your Secondary Server is at:');
    print('   👉 $secondaryUrl');
    
    // Parse the secondary URL
    final parts = secondaryUrl.split(':');
    if (parts.length != 2) {
       print('❌ Error: Invalid secondary URL format');
       exit(1);
    }
    final host = parts[0];
    final port = int.parse(parts[1]);
    
    // 2. Secondary Server Check
    print('\nStep 2: Connecting to Secondary Server ($host:$port)...');
    print('   (This is likely where your sshnpd is timing out)');
    
    final socket = await Socket.connect(host, port, timeout: Duration(seconds: 10));
    print('✅ Success! Connected to Secondary Server.');
    print('   Your network firewall is NOT blocking this connection.');
    
    socket.destroy();
    
  } catch (e) {
    print('\n❌ FAILURE: $e');
    print('\nPossible causes:');
    print('1. Firewall is blocking the port (usually 1024-65535)');
    print('2. DNS resolution failed');
    print('3. The Secondary Server is actually down');
  }
  print('--------------------------------------------------');
}
