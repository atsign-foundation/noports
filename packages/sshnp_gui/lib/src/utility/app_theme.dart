import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

class AppTheme {
  static TextTheme lightTextTheme = const TextTheme(
    // displayLarge: TextStyle(
    //   fontSize: 80,
    //   fontWeight: FontWeight.bold,
    //   // letterSpacing: -1.5,
    // ),
    // displayMedium: TextStyle(
    //   fontSize: 60,
    //   fontWeight: FontWeight.bold,
    //   // letterSpacing: -0.5,
    // ),
    // displaySmall: TextStyle(
    //   fontSize: 48,
    //   fontWeight: FontWeight.w800,
    // ),
    // headlineMedium: TextStyle(
    //   fontSize: 34,
    //   fontWeight: FontWeight.w600,
    //   // letterSpacing: 0.25,
    // ),
    // headlineSmall: TextStyle(
    //   fontSize: 24,
    //   fontWeight: FontWeight.w400,
    // ),
    // titleLarge: TextStyle(
    //   fontSize: 20,
    //   fontWeight: FontWeight.w500,
    //   // letterSpacing: 0.15,
    // ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      // letterSpacing: 0.15,
    ),
    // titleSmall: TextStyle(
    //   fontSize: 14,
    //   fontWeight: FontWeight.w500,
    //   // letterSpacing: 0.1,
    // ),
    bodyLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      // letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      // letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      // letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      // letterSpacing: 1.25,
    ),
    labelMedium: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      // letterSpacing: 1.25,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      // letterSpacing: 1.5,
    ),
  );

  // 2
  static TextTheme darkTextTheme = const TextTheme(
    titleMedium: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      // letterSpacing: 0.15,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      // letterSpacing: 0.1,
    ),
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      // letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      // letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      // letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      // letterSpacing: 1.25,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      // letterSpacing: 1.5,
    ),
  );

  // 3
  static ThemeData light() {
    return ThemeData(
        fontFamily: 'Poppins',
        useMaterial3: true,
        // scaffoldBackgroundColor: kPrimaryColor,

        brightness: Brightness.light,
        colorScheme: const ColorScheme.light().copyWith(
          primary: kPrimaryColor,
          // onPrimary: kOnPrimaryColor,
          // primaryContainer: kPrimaryContainer,
          // onPrimaryContainer: kOnPrimaryContainer,
          // secondary: kSecondaryColor,
          // onSecondary: kOnSecondaryColor,
          // secondaryContainer: kSecondaryContainer,
          // onSecondaryContainer: kOnSecondaryContainer,
          // tertiary: kTertiaryColor,
          // onTertiary: kOnTertiaryColor,
          // tertiaryContainer: kTertiaryContainer,
          // onTertiaryContainer: kOnTertiaryContainer,
          // error: kErrorColor,
          // onError: kOnError,
          // errorContainer: kErrorContainer,
          // onErrorContainer: kOnErrorContainer,
          // background: kBackgroundColor,
          // onBackground: kOnBackground,
          // surface: kSurface,
          // onSurface: kOnSurface,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateColor.resolveWith(
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
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.0),
              ),
            ),
            backgroundColor: MaterialStateProperty.all<Color>(const Color(0xFF12DE26)),
            foregroundColor: MaterialStateProperty.all<Color>(const Color(0xFFFFFFFF)),
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

  // 4
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark().copyWith(primary: kPrimaryColor, background: kBackGroundColorDark
          // onPrimary: kOnPrimaryColor,
          // primaryContainer: kPrimaryContainer,
          // onPrimaryContainer: kOnPrimaryContainer,
          // secondary: kSecondaryColor,
          // onSecondary: kOnSecondaryColor,
          // secondaryContainer: kSecondaryContainer,
          // onSecondaryContainer: kOnSecondaryContainer,
          // tertiary: kTertiaryColor,
          // onTertiary: kOnTertiaryColor,
          // tertiaryContainer: kTertiaryContainer,
          // onTertiaryContainer: kOnTertiaryContainer,
          // error: kErrorColor,
          // onError: kOnError,
          // errorContainer: kErrorContainer,
          // onErrorContainer: kOnErrorContainer,
          // background: kBackgroundColor,
          // onBackground: kOnBackground,
          // surface: kSurface,
          // onSurface: kOnSurface,
          ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateColor.resolveWith(
          (states) {
            return Colors.black;
          },
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        foregroundColor: Color(0xFFF8C630),
        backgroundColor: Colors.black,
      ),
      textTheme: darkTextTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              side: const BorderSide(
                width: 1,
                color: Color(0xFF707070),
              ),
              borderRadius: BorderRadius.circular(Sizes.p3),
            ),
          ),
          backgroundColor: MaterialStateProperty.all<Color>(const Color(0xFF2F2F2F)),
          foregroundColor: MaterialStateProperty.all<Color>(const Color(0xFF707070)),
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
          // minimumSize: const Size(48, 43),
          // maximumSize: const Size(48, 43),
        ),
      ),
    );
  }

  static MacosThemeData macosDark() {
    return MacosThemeData(brightness: Brightness.dark, primaryColor: kPrimaryColor);
  }
}
