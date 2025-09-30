import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_utils/at_logger.dart';
import 'package:npt_flutter/features/logging/models/logging_bloc.dart';
import 'package:npt_flutter/features/policy/cubit/status_light/policy_status_light_state.dart';

final class PolicyStatusLightCubit extends LoggingCubit<PolicyStatusLightState> {
  PolicyStatusLightCubit() : super(const PolicyStatusLightInitial());

  final AtSignLogger logger = AtSignLogger('PolicyStatusLightCubit');
  static const Duration _freshThreshold = Duration(seconds: 10);

  Future<void> loadStatusLight() async {
    try {
      final AtClient atClient = AtClientManager.getInstance().atClient;

      final AtKey atKey = AtKey()
        ..key = 'heartbeat'
        ..sharedBy = atClient.getCurrentAtSign();

      final GetRequestOptions requestOptions = GetRequestOptions()
        ..useRemoteAtServer = true;

      final AtValue atValue = await atClient.get(
        atKey,
        getRequestOptions: requestOptions,
      );

      final dynamic rawValue = atValue.value;

      if (rawValue == null || (rawValue is String && rawValue.trim().isEmpty)) {
        final String msg = 'Heartbeat value for ${atKey.toString()} is empty';
        emit(
          PolicyStatusLightLoaded(
            lightState: LightState.red,
            message: msg,
          ),
        );
        logger.severe(msg);
        return;
      }

      if (rawValue is! String) {
        final String msg = 'Unexpected heartbeat value type: ${rawValue.runtimeType}';
        emit(
          PolicyStatusLightLoaded(
            lightState: LightState.red,
            message: msg,
          ),
        );
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
        emit(
          PolicyStatusLightLoaded(
            lightState: LightState.red,
            message: msg,
          ),
        );
        logger.severe(msg);
        return;
      }

      final Object? timestampObject = payload['timestamp'];
      if (timestampObject is! String || timestampObject.trim().isEmpty) {
        final String msg = 'Heartbeat payload missing timestamp: $payload';
        emit(
          PolicyStatusLightLoaded(
            lightState: LightState.red,
            message: msg,
          ),
        );
        logger.severe(msg);
        return;
      }

      final DateTime? timestamp = DateTime.tryParse(timestampObject);
      if (timestamp == null) {
        final String msg = 'Unable to parse heartbeat timestamp: $timestampObject';
        emit(
          PolicyStatusLightLoaded(
            lightState: LightState.red,
            message: msg,
          ),
        );
        logger.severe(msg);
        return;
      }

      final DateTime nowUtc = DateTime.now().toUtc();
      final DateTime heartbeatUtc = timestamp.toUtc();
      final Duration delta = nowUtc.difference(heartbeatUtc);

      bool isFresh = false;
      if (!delta.isNegative) {
        isFresh = delta <= _freshThreshold;
      }

      final LightState lightState = isFresh ? LightState.green : LightState.red;
      final String message = _buildMessage(delta, heartbeatUtc);

      emit(
        PolicyStatusLightLoaded(
          lightState: lightState,
          message: message,
        ),
      );
    } catch (error) {
      final String msg = 'Failed to load policy heartbeat: $error';
      emit(
        PolicyStatusLightLoaded(
          lightState: LightState.red,
          message: msg,
        ),
      );
      logger.severe(msg);
    }
  }

  String _buildMessage(Duration delta, DateTime heartbeatUtc) {
    if (delta.isNegative) {
      return 'Heartbeat expected in ${_formatDuration(delta.abs())}';
    }
    if (delta < const Duration(seconds: 5)) {
      return 'Last heartbeat just now';
    }
    return 'Last heartbeat ${_formatDuration(delta)} ago (${heartbeatUtc.toLocal().toIso8601String()})';
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
