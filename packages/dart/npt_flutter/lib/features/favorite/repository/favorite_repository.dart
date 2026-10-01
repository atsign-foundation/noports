import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/util/constants.dart';

class FavoriteRepository {
  final AtClient? _atClient;
  Map<String, Favorite>? _favoriteCache;

  FavoriteRepository({AtClient? atClient}) : _atClient = atClient;

  AtClient get _client => _atClient ?? AtClientManager.getInstance().atClient;

  static AtKey getFavoriteAtKey({String? sharedBy}) {
    var key = AtKey.self(
      Constants.favoriteKeyName,
      namespace: Constants.namespace,
    );
    if (sharedBy != null) key.sharedBy(sharedBy);
    return key.build();
  }

  Future<Map<String, Favorite>?> getFavorites({bool useCache = true}) async {
    if (useCache && _favoriteCache != null) return _favoriteCache;
    _favoriteCache = null;
    final Map<String, Favorite> loadedFavorites = {};

    Atsign? atsign = _client.getCurrentAtSign()?.toAtsign();
    AtKey key = getFavoriteAtKey(sharedBy: atsign);

    try {
      var value = await _client.get(key);
      if (value.value == null) {
        _favoriteCache = loadedFavorites;
        return _favoriteCache;
      }
      var json = jsonDecode(value.value);
      if (json is! Map) {
        throw 'favorites from the atServer is not a Map';
      }

      for (final key in json.keys) {
        if (json[key] is! Map) continue;
        final fav = Favorite.fromJson(json[key]);
        if (fav == null) continue;
        loadedFavorites[fav.uuid] = fav;
      }
      _favoriteCache = loadedFavorites;
    } catch (e) {
      App.log('[ERROR] getFavorites: $e'.loggable);
    }
    return _favoriteCache ?? loadedFavorites;
  }

  Future<bool> _putFavorites() async {
    Atsign? atsign = _client.getCurrentAtSign()?.toAtsign();
    AtKey key = getFavoriteAtKey(sharedBy: atsign);
    try {
      return await _client.put(key, jsonEncode(_favoriteCache));
    } catch (e) {
      App.log('[ERROR] _putFavorites: $e'.loggable);
      return false;
    }
  }

  Future<bool> addFavorite(Favorite favorite) async {
    if (!await _initializeCache()) return false;
    _favoriteCache![favorite.uuid] = favorite;
    return _putFavorites();
  }

  Future<bool> removeFavorites(Iterable<String> uuids) async {
    if (!await _initializeCache()) return false;
    for (final uuid in uuids) {
      _favoriteCache!.remove(uuid);
    }
    return _putFavorites();
  }

  Future<bool> _initializeCache() async {
    if (_favoriteCache == null) await getFavorites();
    return _favoriteCache != null;
  }
}
