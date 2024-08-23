import 'package:npt_flutter/features/favorite/favorite.dart';

mixin Favoritable {
  bool isInFavorites(Iterable<Favorite> favorites) {
    for (final fav in favorites) {
      if (fav.isFavoriteMatch(this)) {
        return true;
      }
    }
    return false;
  }
}
