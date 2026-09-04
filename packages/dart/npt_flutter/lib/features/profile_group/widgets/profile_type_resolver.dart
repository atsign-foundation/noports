import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';

typedef ProfileTypeBuilder =
    Widget Function(BuildContext context, Map<String, ProfileType> types);

/// Tracks the [ProfileType] of every profile in [uuids] by listening to the
/// cached [ProfileBloc]s, so the type buckets follow edits in real time.
/// Profiles which have not finished loading are reported as [ProfileType.none].
class ProfileTypeResolver extends StatefulWidget {
  final List<String> uuids;
  final ProfileTypeBuilder builder;
  const ProfileTypeResolver({
    required this.uuids,
    required this.builder,
    super.key,
  });

  @override
  State<ProfileTypeResolver> createState() => _ProfileTypeResolverState();
}

class _ProfileTypeResolverState extends State<ProfileTypeResolver> {
  final Map<String, StreamSubscription<ProfileState>> _subscriptions =
      <String, StreamSubscription<ProfileState>>{};
  final Map<String, ProfileType> _types = <String, ProfileType>{};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ProfileTypeResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    for (final StreamSubscription<ProfileState> sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  static ProfileType _typeOf(ProfileState state) {
    if (state is ProfileLoadedState)
      return ProfileType.fromProfile(state.profile);
    return ProfileType.none;
  }

  void _sync() {
    final ProfileCacheCubit cache = context.read<ProfileCacheCubit>();
    final Set<String> wanted = widget.uuids.toSet();

    for (final String uuid in _subscriptions.keys.toList()) {
      if (wanted.contains(uuid)) continue;
      _subscriptions.remove(uuid)?.cancel();
      _types.remove(uuid);
    }

    for (final String uuid in wanted) {
      if (_subscriptions.containsKey(uuid)) continue;
      final ProfileBloc bloc = cache.getProfileBloc(uuid);
      _types[uuid] = _typeOf(bloc.state);
      if (bloc.state is ProfileInitial) {
        bloc.add(const ProfileLoadEvent());
      }
      _subscriptions[uuid] = bloc.stream.listen((ProfileState state) {
        final ProfileType type = _typeOf(state);
        if (_types[uuid] == type || !mounted) return;
        setState(() => _types[uuid] = type);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      Map<String, ProfileType>.unmodifiable(_types),
    );
  }
}
