import 'package:flutter/material.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';

/// Light theme matching npt_flutter. There is intentionally no dark theme
/// yet, to stay in step with NoPorts Desktop.
class AppTheme {
  static const TextTheme textTheme = TextTheme(
    headlineLarge: TextStyle(fontSize: Sizes.p32, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontSize: Sizes.p24, fontWeight: FontWeight.w500),
    headlineSmall: TextStyle(fontSize: Sizes.p18, fontWeight: FontWeight.w500),
    titleLarge: TextStyle(fontSize: Sizes.p16, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: Sizes.p14, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: Sizes.p12, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: Sizes.p16, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(fontSize: Sizes.p14, fontWeight: FontWeight.w500),
    bodySmall: TextStyle(fontSize: Sizes.p12, fontWeight: FontWeight.w400),
  );

  static OutlineInputBorder _border(Color color, double width) =>
      OutlineInputBorder(
        borderSide: BorderSide(color: color, width: width),
        borderRadius: const BorderRadius.all(Radius.circular(Sizes.p10)),
      );

  static ThemeData light() {
    return ThemeData(
      fontFamily: 'Poppins',
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColor.surfaceColor,
      colorScheme: const ColorScheme.light().copyWith(
        primary: AppColor.primaryColor,
        surface: AppColor.surfaceColor,
        onSurface: AppColor.onSurfaceColorAlt,
        onSurfaceVariant: AppColor.onSurfaceColor,
        surfaceTint: Colors.transparent,
        error: AppColor.errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.p16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColor.onSurfaceColorAlt,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColor.onSurfaceColor),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(102, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.p6),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColor.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(102, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.p6),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColor.onSurfaceColorAlt,
          minimumSize: const Size(102, 44),
          side: const BorderSide(color: AppColor.dividerColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.p6),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        checkColor: WidgetStateProperty.all(AppColor.primaryColor),
        side: const BorderSide(color: AppColor.primaryColor, width: Sizes.p2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColor.primaryColor
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColor.primaryColorButtonBackground
              : AppColor.greyColor,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.white,
        filled: true,
        isDense: true,
        hoverColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Sizes.p12,
          vertical: Sizes.p12,
        ),
        enabledBorder: _border(AppColor.textFieldBorderColor, Sizes.p2),
        focusedBorder: _border(AppColor.primaryColor, Sizes.p2),
        disabledBorder: _border(AppColor.greyColor, Sizes.p2),
        errorBorder: _border(AppColor.errorColor, Sizes.p2),
        focusedErrorBorder: _border(AppColor.errorColor, Sizes.p2),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          fillColor: Colors.white,
          filled: true,
          isDense: true,
          enabledBorder: _border(AppColor.textFieldBorderColor, Sizes.p2),
          focusedBorder: _border(AppColor.primaryColor, Sizes.p2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColor.dividerColorAlt,
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: TextStyle(color: AppColor.onSurfaceColorAlt),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
