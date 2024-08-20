part of 'profiles_selected_cubit.dart';

final class ProfilesSelectedState extends Loggable {
  final Set<String> selected;
  const ProfilesSelectedState(this.selected);

  ProfilesSelectedState withAdded(Set<String> uuids) {
    return ProfilesSelectedState(selected.union(uuids));
  }

  ProfilesSelectedState withRemoved(Set<String> uuids) {
    return ProfilesSelectedState(selected.difference(uuids));
  }

  @override
  List<Object?> get props => [selected];

  @override
  String toString() {
    return 'ProfilesSelectedState($selected)';
  }
}
