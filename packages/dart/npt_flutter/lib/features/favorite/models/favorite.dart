import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';

part 'favorite.g.dart';

enum FavoriteType {
  profile('profile');

  //profileGroup, //TODO
  final String jsonKey;
  const FavoriteType(this.jsonKey);

  static FavoriteType? fromJsonKey(String key) {
    return switch (key) {
      'profile' => profile,
      _ => null,
    };
  }
}

sealed class Favorite extends Loggable {
  final String uuid;
  final FavoriteType type;

  Future<String?> get displayName;
  bool? get isRunning;
  bool isFavoriteMatch(Favoritable favoritable);
  void toggle();

  const Favorite({required this.uuid, required this.type});

  static const _typeKey = 'type';

  /// [fromJson] is a multi stage process in this class
  /// first we extract [type] from [json] then we use the
  /// appropriate factory of that type's associated class
  static Favorite? fromJson(Map<String, dynamic> json) {
    var type = FavoriteType.fromJsonKey(json[_typeKey]);

    return switch (type) {
      null => null,
      FavoriteType.profile => FavoriteProfile.fromJson(json),
    };
  }

  /// [mustCallSuper] is a reminder to include [type] in the json
  @mustCallSuper
  Map<String, dynamic> toJson() {
    return {_typeKey: type.jsonKey};
  }
}

@JsonSerializable()
class FavoriteProfile extends Favorite {
  const FavoriteProfile({required super.uuid})
      : super(type: FavoriteType.profile);

  @override
  List<Object?> get props => [uuid];

  @override
  String toString() {
    return 'FavoriteProfile(uuid: $uuid)';
  }

  factory FavoriteProfile.fromJson(Map<String, dynamic> json) =>
      _$FavoriteProfileFromJson(json);

  @override
  Map<String, dynamic> toJson() {
    var json = _$FavoriteProfileToJson(this);
    json.addAll(super.toJson());
    return json;
  }

  @override
  Future<String?> get displayName async {
    var context = App.navState.currentContext;
    if (context == null) return null;
    var repo = context.read<ProfileRepository>();
    var profile = await repo.getProfile(uuid);
    if (profile == null) return null;
    return profile.displayName;
  }

  @override
  bool? get isRunning {
    var context = App.navState.currentContext;
    if (context == null) return null;
    var cubit = context.read<ProfilesRunningCubit>();

    return cubit.state.socketConnectors.containsKey(uuid) &&
        !cubit.state.socketConnectors[uuid]!.closed;
  }

  @override
  bool isFavoriteMatch(Favoritable favoritable) {
    if (favoritable is! Profile) return false;
    return favoritable.uuid == uuid;
  }

  @override
  void toggle() {
    var context = App.navState.currentContext;
    if (context == null) return;

    final isRunning = this.isRunning;
    if (isRunning == null) return;
    var cache = context.read<ProfileCacheCubit>();
    if (isRunning) {
      cache.getProfileBloc(uuid).add(const ProfileStopEvent());
    } else {
      cache.getProfileBloc(uuid).add(const ProfileStartEvent());
    }
  }
}
