part of 'profile_folder_bloc.dart';

sealed class ProfileFolderState extends Loggable {
  const ProfileFolderState();

  @override
  List<Object?> get props => [];
}

final class ProfileFoldersInitial extends ProfileFolderState {
  const ProfileFoldersInitial();

  @override
  String toString() {
    return 'ProfileFoldersInitial';
  }
}

final class ProfileFoldersLoading extends ProfileFolderState {
  const ProfileFoldersLoading();

  @override
  String toString() {
    return 'ProfileFoldersLoading';
  }
}

final class ProfileFoldersFailedLoad extends ProfileFolderState {
  const ProfileFoldersFailedLoad();

  @override
  String toString() {
    return 'ProfileFoldersFailedLoad';
  }
}

final class ProfileFoldersLoaded extends ProfileFolderState {
  final ProfileFolderData data;
  const ProfileFoldersLoaded(this.data);

  List<ProfileFolder> get folders => data.folders;

  @override
  List<Object?> get props => [data];

  @override
  String toString() {
    return 'ProfileFoldersLoaded($data)';
  }
}
