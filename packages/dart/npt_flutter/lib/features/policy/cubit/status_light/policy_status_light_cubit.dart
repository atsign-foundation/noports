import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:npt_flutter/features/logging/models/logging_bloc.dart';
import 'package:npt_flutter/features/policy/cubit/status_light/policy_status_light_state.dart';

final class PolicyStatusLightCubit
    extends LoggingCubit<PolicyStatusLightState> {
  PolicyStatusLightCubit() : super(const PolicyStatusLightInitial());

  final AtSignLogger logger = AtSignLogger('PolicyStatusLightCubit');

  /// Just reads the heartbeat key then emits state accordingly
  Future<void> loadStatusLight() async {
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

      final DateTime nowUtc = DateTime.now().toUtc();
      final DateTime heartbeatUtc = timestamp.toUtc();
      final Duration delta = nowUtc.difference(heartbeatUtc);

      bool isFresh = false;
      if (!delta.isNegative) {
        // e.g. if interval is 60 seconds, then heartbeat is fresh if last heartbeat was within the last 60 seconds
        isFresh = delta <= interval;
      }

      final LightState lightState = isFresh ? LightState.green : LightState.red;
      final String message = _buildMessage(delta, heartbeatUtc);

      emit(PolicyStatusLightLoaded(lightState: lightState, message: message));
    } catch (error) {
      final String msg = 'Failed to load policy heartbeat: $error';
      emit(PolicyStatusLightLoaded(lightState: LightState.red, message: msg));
      logger.severe(msg);
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
      baseNameSpace: 'sshnp.noports',
      domainNameSpace: 'npp_atserver_heartbeat',
    );

    final Future<Map<String, dynamic>> rpcFuture = rpc.call({});

    const int timeoutSeconds = 10;
    rpcFuture.timeout(const Duration(seconds: timeoutSeconds), onTimeout: () {
      emit(const PolicyStatusLightLoaded(lightState: LightState.clear, message: 'Heartbeat RPC call timed out after $timeoutSeconds seconds...'));
      return {'success': false};
    });

    final Map<String, dynamic> response = await rpcFuture;

    if (!response['success']) {
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
    await loadStatusLight();
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
