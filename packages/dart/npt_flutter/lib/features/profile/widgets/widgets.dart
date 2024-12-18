// Profile widgets
//
// N.B. Most of these widgets must be wrapped in a BlocProvider for ProfileBloc
// Unlike most other blocs there is no ProfileBloc provider in app.dart,
// So verify that there will ALWAYS be an ancestor BlocProvider<ProfileBloc>
// in the tree for the widgets which read / select it

export 'profile_device_name.dart';
export 'profile_display_name.dart';
export 'profile_favorite_button.dart';
export 'profile_popup_menu_button.dart';
export 'profile_refresh_button.dart';
export 'profile_run_button.dart';
export 'profile_select_box.dart';
export 'profile_service_view.dart';
export 'profile_status_indicator.dart';
