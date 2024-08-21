import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';

class ProfileFavoriteButton extends StatelessWidget {
  const ProfileFavoriteButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, Profile?>(selector: (state) {
      if (state is! ProfileLoadedState) return null;
      return state.profile;
    }, builder: (context, profile) {
      if (profile == null) return const SizedBox();
      return BlocSelector<FavoriteBloc, FavoritesState, bool>(
        selector: (FavoritesState state) {
          if (state is! FavoritesLoaded) return false;
          return profile.isInFavorites(state.favorites);
        },
        builder: (BuildContext context, bool isFavorited) => ElevatedButton(
          onPressed: () {
            if (isFavorited) {
              context.read<FavoriteBloc>().add(
                    FavoriteRemoveEvent(FavoriteProfile(uuid: profile.uuid)),
                  );
            } else {
              context.read<FavoriteBloc>().add(
                    FavoriteAddEvent(FavoriteProfile(uuid: profile.uuid)),
                  );
            }
          },
          child: Text(isFavorited ? 'Unfavorite' : 'Favorite'),
        ),
      );
    });
  }
}
