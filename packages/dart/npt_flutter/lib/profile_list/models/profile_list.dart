import 'package:equatable/equatable.dart';

class ProfileList extends Equatable {
  final Iterable<String> profiles;
  const ProfileList(this.profiles);

  @override
  List<Object?> get props => [profiles];
}
