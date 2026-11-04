part of 'profile_folder_bloc.dart';

sealed class ProfileFolderState extends Loggable {
  const ProfileFolderState();

  /// Folders can change only once loaded and caught up with the atServer.
  bool get editable => false;

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

  /// False while the local copy may be older than the atServer's.
  final bool synced;
  const ProfileFoldersLoaded(this.data, {this.synced = true});

  List<ProfileFolder> get folders => data.folders;

  @override
  bool get editable => synced;

  @override
  List<Object?> get props => [data, synced];

  @override
  String toString() {
    return 'ProfileFoldersLoaded($data, synced: $synced)';
  }
}
