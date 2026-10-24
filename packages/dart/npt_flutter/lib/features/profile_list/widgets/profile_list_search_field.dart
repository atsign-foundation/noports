import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileListSearchField extends StatefulWidget {
  const ProfileListSearchField({super.key});

  @override
  State<ProfileListSearchField> createState() => _ProfileListSearchFieldState();
}

class _ProfileListSearchFieldState extends State<ProfileListSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: context.read<ProfileListFilterCubit>().state.query,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    context.read<ProfileListFilterCubit>().search(query);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return SizedBox(
      width: Sizes.p240,
      child: TextField(
        key: const Key('ProfileListSearchField'),
        controller: _controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: strings.profileSearchHint,
          isDense: true,
          constraints: const BoxConstraints(maxHeight: Sizes.p44),
          prefixIcon: PhosphorIcon(
            PhosphorIcons.magnifyingGlass(),
            size: Sizes.p16,
          ),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: strings.profileSearchClear,
                  icon: PhosphorIcon(PhosphorIcons.x(), size: Sizes.p16),
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}
