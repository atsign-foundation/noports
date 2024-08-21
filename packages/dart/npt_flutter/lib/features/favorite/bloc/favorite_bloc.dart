import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/tray_manager/tray_manager.dart';

part 'favorite_event.dart';
part 'favorite_state.dart';

class FavoriteBloc extends LoggingBloc<FavoriteEvent, FavoritesState> {
  final FavoriteRepository _repo;
  FavoriteBloc(this._repo) : super(const FavoritesInitial()) {
    on<FavoriteLoadEvent>(_onLoad);
    on<FavoriteAddEvent>(_onAdd);
    on<FavoriteRemoveEvent>(_onRemove);
  }

  FutureOr<void> _onLoad(
      FavoriteLoadEvent event, Emitter<FavoritesState> emit) async {
    emit(const FavoritesLoading());

    Map<String, Favorite>? favs;
    try {
      favs = await _repo.getFavorites();
    } catch (e) {
      favs = null;
    }

    if (favs == null) {
      emit(const FavoritesLoaded([]));
      return;
    }
    emit(FavoritesLoaded(favs.values));
    App.navState.currentContext?.read<TrayCubit>().reloadFavorites();
  }

  FutureOr<void> _onAdd(
      FavoriteAddEvent event, Emitter<FavoritesState> emit) async {
    if (state is! FavoritesLoaded) {
      return;
    }

    emit(FavoritesLoaded(
      [...(state as FavoritesLoaded).favorites, event.favorite],
    ));
    App.navState.currentContext?.read<TrayCubit>().reloadFavorites();
    try {
      await _repo.addFavorite(event.favorite);
    } catch (_) {}
  }

  FutureOr<void> _onRemove(
      FavoriteRemoveEvent event, Emitter<FavoritesState> emit) async {
    if (state is! FavoritesLoaded) {
      return;
    }

    emit(FavoritesLoaded(
      (state as FavoritesLoaded)
          .favorites
          .toSet()
          .difference(event.toRemove.toSet()),
    ));

    App.navState.currentContext?.read<TrayCubit>().reloadFavorites();
    try {
      var profileIds = <String>{};
      for (Favorite fav in event.toRemove) {
        profileIds.addAll(fav.profileIds);
      }
      await _repo.removeFavorites(profileIds);
    } catch (_) {}
  }
}
