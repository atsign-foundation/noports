part of 'favorite_bloc.dart';

sealed class FavoriteEvent extends Loggable {
  const FavoriteEvent();

  @override
  List<Object?> get props => [];
}

final class FavoriteLoadEvent extends FavoriteEvent {
  const FavoriteLoadEvent();
  @override
  String toString() {
    return 'FavoriteLoadEvent';
  }
}

final class FavoriteAddEvent extends FavoriteEvent {
  final Favorite favorite;
  const FavoriteAddEvent(this.favorite);

  @override
  List<Object?> get props => [favorite];

  @override
  String toString() {
    return 'FavoriteAddEvent($favorite)';
  }
}

final class FavoriteRemoveEvent extends FavoriteEvent {
  final Iterable<Favorite> toRemove;
  const FavoriteRemoveEvent(this.toRemove);

  @override
  List<Object?> get props => [toRemove];

  @override
  String toString() {
    return 'FavoriteRemoveEvent($toRemove)';
  }
}
