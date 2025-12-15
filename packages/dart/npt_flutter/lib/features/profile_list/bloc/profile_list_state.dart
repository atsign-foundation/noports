part of 'profile_list_bloc.dart';

enum SortColumn { profileName, deviceName, serviceMapping, status }

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
  final String searchQuery;
  const ProfileListLoaded({
    required this.profiles,
    this.sortColumn = SortColumn.profileName,
    this.sortOrder = SortOrder.ascending,
    this.searchQuery = '',
  });

  ProfileListLoaded copyWith({
    Iterable<String>? profiles,
    SortColumn? sortColumn,
    SortOrder? sortOrder,
    String? searchQuery,
  }) {
    return ProfileListLoaded(
      profiles: profiles ?? this.profiles,
      sortColumn: sortColumn ?? this.sortColumn,
      sortOrder: sortOrder ?? this.sortOrder,
      // searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object> get props => [profiles, sortColumn, sortOrder, searchQuery];

  @override
  String toString() {
    return 'ProfileListLoaded(profiles: $profiles, sortColumn: $sortColumn, sortOrder: $sortOrder, searchQuery: $searchQuery)';
  }
}

final class ProfileListFailedLoad extends ProfileListState {
  const ProfileListFailedLoad();

  @override
  String toString() {
    return 'ProfileListFailedLoad';
  }
}
