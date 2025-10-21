part of 'profile_list_bloc.dart';

enum SortColumn { profileName, deviceName, serviceMapping, status, none }

enum SortOrder { ascending, descending }

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
  final SortColumn sortColumn;
  final SortOrder sortOrder;
  const ProfileListLoaded({
    required this.profiles,
    this.sortColumn = SortColumn.none,
    this.sortOrder = SortOrder.ascending,
  });

  ProfileListLoaded copyWith({
    Iterable<String>? profiles,
    SortColumn? sortColumn,
    SortOrder? sortOrder,
  }) {
    return ProfileListLoaded(
      profiles: profiles ?? this.profiles,
      sortColumn: sortColumn ?? this.sortColumn,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object> get props => [profiles, sortColumn, sortOrder];

  @override
  String toString() {
    return 'ProfileListLoaded(profiles: $profiles, sortColumn: $sortColumn, sortOrder: $sortOrder)';
  }
}

final class ProfileListFailedLoad extends ProfileListState {
  const ProfileListFailedLoad();

  @override
  String toString() {
    return 'ProfileListFailedLoad';
  }
}
