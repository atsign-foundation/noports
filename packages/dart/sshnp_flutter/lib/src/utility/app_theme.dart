import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

class AppTheme {
  static TextTheme lightTextTheme = const TextTheme(
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w400,
    ),
  );

  static TextTheme darkTextTheme = const TextTheme(
    titleMedium: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    bodyMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    bodySmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w400,
    ),
  );

  static ThemeData light() {
    return ThemeData(
        fontFamily: 'Poppins',
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light().copyWith(
          primary: kPrimaryColor,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateColor.resolveWith(
            (states) {
              return Colors.black;
            },
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          foregroundColor: Color(0xFFF8C630),
          backgroundColor: Colors.black,
        ),
        textTheme: lightTextTheme,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.0),
              ),
            ),
            backgroundColor: WidgetStateProperty.all<Color>(const Color(0xFF12DE26)),
            foregroundColor: WidgetStateProperty.all<Color>(const Color(0xFFFFFFFF)),
          ),
        ),
        dialogTheme: const DialogTheme(
          surfaceTintColor: kPrimaryColor,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          surfaceTintColor: kPrimaryColor,
          color: const Color(0xFFF4F4F4),
          shape: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide.none,
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          useIndicator: false,
          backgroundColor: kPrimaryColor,
        ),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.p8),
          ),
        )));
  }

  static ThemeData dark() {
    return ThemeData(
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark().copyWith(primary: kPrimaryColor, surface: kBackGroundColorDark),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateColor.resolveWith(
          (states) {
            return Colors.black;
          },
        ),
      ),
      floatingActionButtonTheme:
          const FloatingActionButtonThemeData(foregroundColor: Colors.white, backgroundColor: kPrimaryColor),
      textTheme: darkTextTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              side: const BorderSide(
                width: 1,
                color: Color(0xFF707070),
              ),
              borderRadius: BorderRadius.circular(Sizes.p3),
            ),
          ),
          backgroundColor: WidgetStateProperty.all<Color>(const Color(0xFF2F2F2F)),
          foregroundColor: WidgetStateProperty.all<Color>(const Color(0xFF707070)),
        ),
      ),
      dialogTheme: const DialogTheme(
        surfaceTintColor: kProfileFormFieldColor,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        surfaceTintColor: kPrimaryColor,
        color: const Color(0xFFF4F4F4),
        shape: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        useIndicator: false,
        backgroundColor: kPrimaryColor,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.p5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          fixedSize: const Size(48, 43),
        ),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: kPrimaryColor, systemOverlayStyle: SystemUiOverlayStyle.light),
    );
  }

  static MacosThemeData macosDark() {
    return MacosThemeData(brightness: Brightness.dark, primaryColor: kPrimaryColor);
  }
}
