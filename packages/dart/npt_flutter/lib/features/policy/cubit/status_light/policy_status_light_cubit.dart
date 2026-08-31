import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:npt_flutter/features/logging/models/logging_bloc.dart';
import 'package:npt_flutter/features/policy/cubit/status_light/policy_status_light_state.dart';
import 'package:version/version.dart';

final class PolicyStatusLightCubit
    extends LoggingCubit<PolicyStatusLightState> {
  PolicyStatusLightCubit() : super(const PolicyStatusLightInitial());

  static const String _minHeartbeatCoreVersion = '6.8.1';

  final AtSignLogger logger = AtSignLogger('PolicyStatusLightCubit');

  bool _isLoading = false;

  PolicyStatusLightLoaded? _cachedVersionCheckResult;

  Future<void> loadStatusLight() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final AtClient atClient = AtClientManager.getInstance().atClient;

      final AtKey atKey = AtKey()
        ..key = 'heartbeat'
        ..sharedBy = atClient.getCurrentAtSign()
        ..namespace = 'sshnp';

      final AtValue atValue = await atClient.get(
        atKey,
        getRequestOptions: GetRequestOptions()..useRemoteAtServer = true,
      );

      final dynamic rawValue = atValue.value;

      if (rawValue == null || (rawValue is String && rawValue.trim().isEmpty)) {
        final String msg = 'Heartbeat value for ${atKey.toString()} is empty';
        emit(PolicyStatusLightLoaded(lightState: LightState.red, message: msg));
        logger.severe(msg);
        return;
      }

      if (rawValue is! String) {
        final String msg =
            'Unexpected heartbeat value type: ${rawValue.runtimeType}';
        emit(PolicyStatusLightLoaded(lightState: LightState.red, message: msg));
        logger.severe(msg);
        return;
      }

      Map<String, dynamic> payload;
      try {
        final dynamic decoded = jsonDecode(rawValue);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Heartbeat payload is not a JSON object');
        }
        payload = decoded;
      } catch (e) {
        final String msg = 'Failed to parse heartbeat payload: $e';
        emit(PolicyStatusLightLoaded(lightState: LightState.red, message: msg));
        logger.severe(msg);
        return;
      }

      final Object? timestampObject = payload['timestamp'];
      if (timestampObject is! String || timestampObject.trim().isEmpty) {
        final String msg = 'Heartbeat payload missing timestamp: $payload';
        emit(PolicyStatusLightLoaded(lightState: LightState.red, message: msg));
        logger.severe(msg);
        return;
      }

      final DateTime? timestamp = DateTime.tryParse(timestampObject);
      if (timestamp == null) {
        final String msg =
            'Unable to parse heartbeat timestamp: $timestampObject';
        emit(PolicyStatusLightLoaded(lightState: LightState.red, message: msg));
        logger.severe(msg);
        return;
      }

      final Object? intervalObject = payload['interval'];
      if (intervalObject is! int || intervalObject <= 0) {
        final String msg = 'Heartbeat payload missing or invalid interval: $payload';
        emit(PolicyStatusLightLoaded(lightState: LightState.red, message: msg));
        logger.severe(msg);
        return;
      }

      final Duration interval = Duration(seconds: intervalObject);

      final DateTime nowUtc = DateTime.timestamp().toUtc();
      final DateTime heartbeatUtc = timestamp.toUtc();
      final Duration delta = nowUtc.difference(heartbeatUtc);

      bool isFresh = !delta.isNegative && delta <= interval;

      logger.info('Heartbeat check: nowUtc=$nowUtc, heartbeatUtc=$heartbeatUtc, delta=$delta, interval=$interval, isFresh=$isFresh');

      final LightState lightState = isFresh ? LightState.green : LightState.red;
      final String message = _buildMessage(delta, heartbeatUtc);

      _cachedVersionCheckResult = null;
      emit(PolicyStatusLightLoaded(lightState: lightState, message: message));
    } catch (error) {
      logger.severe('Failed to load policy heartbeat: $error');
      if (_cachedVersionCheckResult != null) {
        emit(_cachedVersionCheckResult!);
      } else {
        await _checkServerVersion(error.toString());
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _checkServerVersion(String originalError) async {
    try {
      final AtClient atClient = AtClientManager.getInstance().atClient;
      final currentAtSign = atClient.getCurrentAtSign();
      if (currentAtSign == null) {
        const result = PolicyStatusLightLoaded(
          lightState: LightState.red,
          message: 'Unable to reach policy server',
        );
        _cachedVersionCheckResult = result;
        emit(result);
        return;
      }

      final rpc = AtRpcClient(
        serverAtsign: currentAtSign,
        atClient: atClient,
        baseNameSpace: 'sshnp',
        domainNameSpace: 'npp',
      );

      final Map<String, dynamic> response = await rpc
          .call({'operation': 'ping'})
          .timeout(const Duration(seconds: 10));

      final String? coreVersionStr = response['coreVersion'] as String?;
      if (coreVersionStr == null) {
        const result = PolicyStatusLightLoaded(
          lightState: LightState.red,
          message: 'Policy server responded but did not report a version',
        );
        _cachedVersionCheckResult = result;
        emit(result);
        return;
      }

      try {
        final Version serverVersion = Version.parse(coreVersionStr);
        final Version minVersion = Version.parse(_minHeartbeatCoreVersion);

        if (serverVersion < minVersion) {
          final result = PolicyStatusLightLoaded(
            lightState: LightState.yellow,
            message:
                'Policy server v$coreVersionStr does not support heartbeat (requires v$_minHeartbeatCoreVersion+)',
          );
          _cachedVersionCheckResult = result;
          emit(result);
          return;
        }
      } on FormatException {
        final result = PolicyStatusLightLoaded(
          lightState: LightState.yellow,
          message:
              'Policy server reported unrecognized version: $coreVersionStr',
        );
        _cachedVersionCheckResult = result;
        emit(result);
        return;
      }

      final result = PolicyStatusLightLoaded(
        lightState: LightState.red,
        message: 'Policy server is reachable but heartbeat unavailable: $originalError',
      );
      _cachedVersionCheckResult = result;
      emit(result);
    } catch (e) {
      logger.severe('Version check failed: $e');
      const result = PolicyStatusLightLoaded(
        lightState: LightState.red,
        message: 'Unable to reach policy server',
      );
      _cachedVersionCheckResult = result;
      emit(result);
    }
  }

  Future<void> forceHeartbeat() async {
    emit(const PolicyStatusLightLoading());

    final AtClient atClient = AtClientManager.getInstance().atClient;

    if (atClient.getCurrentAtSign() == null) {
      emit(
        const PolicyStatusLightLoaded(
          lightState: LightState.red,
          message:
              'unknown error occurred... atClient.getCurrentAtSign() is null',
        ),
      );
      return;
    }

    final rpc = AtRpcClient(
      serverAtsign: atClient.getCurrentAtSign()!,
      atClient: atClient,
      baseNameSpace: 'sshnp',
      domainNameSpace: 'npp_atserver_heartbeat',
    );

    try {
      final Map<String, dynamic> response = await rpc
          .call({})
          .timeout(const Duration(seconds: 10));

      if (response['success'] != true) {
        emit(
          PolicyStatusLightLoaded(
            lightState: LightState.red,
            message:
                'Failed to force heartbeat onto Policy Server: ${response.toString()}',
          ),
        );
        return;
      }

      logger.info('Successfully sent RPC call to force heartbeat');

      await Future.delayed(const Duration(milliseconds: 500));

      emit(const PolicyStatusLightLoading());
      _isLoading = false;
      await loadStatusLight();
    } on TimeoutException {
      emit(const PolicyStatusLightLoaded(
        lightState: LightState.clear,
        message: 'Heartbeat RPC call timed out after 10 seconds',
      ));
    } catch (e) {
      emit(PolicyStatusLightLoaded(
        lightState: LightState.red,
        message: 'Failed to force heartbeat: $e',
      ));
    }
  }

  String _buildMessage(Duration delta, DateTime heartbeatUtc) {
    return 'Last heartbeat ${_formatDuration(delta)} ago';
  }

  String _formatDuration(Duration duration) {
    final int days = duration.inDays;
    final int hours = duration.inHours.remainder(24);
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    final List<String> parts = [];
    if (days > 0) {
      parts.add('${days}d');
    }
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0) {
      parts.add('${minutes}m');
    }
    if (parts.isEmpty) {
      parts.add('${seconds}s');
    }

    return parts.join(' ');
  }
}
