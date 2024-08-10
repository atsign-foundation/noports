part of 'profile_list_bloc.dart';

sealed class ProfileListEvent extends Equatable {
  const ProfileListEvent();

  @override
  List<Object> get props => [];
}

final class ProfileListLoadEvent extends ProfileListEvent {
  const ProfileListLoadEvent();
}

final class ProfileListDoneLoadEvent extends ProfileListEvent {
  final Iterable<String> profiles;
  final bool error;

  const ProfileListDoneLoadEvent({required this.profiles, this.error = false});

  @override
  List<Object> get props => [profiles, error];
}
