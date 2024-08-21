import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';

class FavoriteRepository {
  Map<String, Favorite>? _favoriteCache;
  static AtKey getFavoriteAtKey({String? sharedBy}) {
    var key = AtKey.self(
      'favorites',
      namespace: Constants.namespace,
    );
    if (sharedBy != null) key.sharedBy(sharedBy);
    return key.build();
  }

  Future<Map<String, Favorite>?> getFavorites({bool useCache = true}) async {
    if (useCache && _favoriteCache != null) return _favoriteCache;
    _favoriteCache ??= {};

    AtClient atClient = AtClientManager.getInstance().atClient;
    String? atSign = atClient.getCurrentAtSign();
    AtKey key = getFavoriteAtKey(sharedBy: atSign);

    try {
      var value = await atClient.get(key);
      if (value.value == null) return _favoriteCache;
      var json = jsonDecode(value.value);
      if (json is! Map) {
        throw 'favorites from the atServer is not a Map';
      }

      for (final key in json.keys) {
        if (json[key] is! Map) continue;
        final fav = Favorite.fromJson(json[key]);
        if (fav == null) continue;
        _favoriteCache?[fav.uuid] = fav;
      }
    } catch (e) {
      App.log('[ERROR] getFavorites: $e'.loggable);
    }
    return _favoriteCache;
  }

  Future<bool> _putFavorites() async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    String? atSign = atClient.getCurrentAtSign();
    AtKey key = getFavoriteAtKey(sharedBy: atSign);
    try {
      return await atClient.put(key, jsonEncode(_favoriteCache));
    } catch (e) {
      App.log('[ERROR] _putFavorites: $e'.loggable);
      return false;
    }
  }

  Future<bool> addFavorite(Favorite favorite) async {
    _favoriteCache ??= {};
    _favoriteCache?[favorite.uuid] = favorite;
    return _putFavorites();
  }

  Future<bool> removeFavorites(Iterable<String> uuids) async {
    _favoriteCache ??= {};
    for (final uuid in uuids) {
      _favoriteCache?.remove(uuid);
    }
    return _putFavorites();
  }
}
