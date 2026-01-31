part of 'favorite_bloc.dart';

sealed class FavoritesState extends Loggable {
  const FavoritesState();

  @override
  List<Object?> get props => [];
}

final class FavoritesInitial extends FavoritesState {
  const FavoritesInitial();
  @override
  String toString() {
    return 'FavoritesInitial';
  }
}

final class FavoritesLoading extends FavoritesState {
  const FavoritesLoading();
  @override
  String toString() {
    return 'FavoritesLoading';
  }
}

final class FavoritesLoaded extends FavoritesState {
  final Iterable<Favorite> favorites;
  const FavoritesLoaded(this.favorites);

  @override
  List<Object?> get props => [favorites];

  @override
  String toString() {
    return 'FavoritesLoaded($favorites)';
  }
}
