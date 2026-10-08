part of 'profile_list_bloc.dart';

sealed class ProfileListState extends Loggable {
  const ProfileListState();

  @override
  List<Object> get props => [];
}

final class ProfileListInitial extends ProfileListState {
  const ProfileListInitial();

  @override
  String toString() {
    return 'ProfileListState';
  }
}

final class ProfileListLoading extends ProfileListState {
  const ProfileListLoading();

  @override
  String toString() {
    return 'ProfileListLoading';
  }
}

final class ProfileListLoaded extends ProfileListState {
  final Iterable<String> profiles;
  const ProfileListLoaded({required this.profiles});

  @override
  List<Object> get props => [profiles];

  @override
  String toString() {
    return 'ProfileListLoaded(profiles: $profiles)';
  }
}

final class ProfileListFailedLoad extends ProfileListState {
  const ProfileListFailedLoad();

  @override
  String toString() {
    return 'ProfileListFailedLoad';
  }
}
