part of 'profile_list_bloc.dart';

sealed class ProfileListState extends Equatable {
  const ProfileListState();

  @override
  List<Object> get props => [];
}

final class ProfileListInitial extends ProfileListState {
  const ProfileListInitial();
}

final class ProfileListLoading extends ProfileListState {
  const ProfileListLoading();
}

final class ProfileListLoaded extends ProfileListState {
  final Iterable<String> profiles;
  const ProfileListLoaded({required this.profiles});

  @override
  List<Object> get props => [...profiles];
}

final class ProfileListFailedLoad extends ProfileListState {
  const ProfileListFailedLoad();
}
