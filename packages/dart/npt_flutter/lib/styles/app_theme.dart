import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';

class AppTheme {
  static TextTheme lightTextTheme = const TextTheme(
    titleMedium: TextStyle(
      fontSize: Sizes.p18,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontSize: Sizes.p15,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: TextStyle(
      fontSize: Sizes.p12,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontSize: Sizes.p11,
      fontWeight: FontWeight.w400,
    ),
    // labelLarge: TextStyle(
    //   fontSize: 11,
    //   fontWeight: FontWeight.w500,
    // ),
    // labelMedium: TextStyle(
    //   fontSize: 11,
    //   fontWeight: FontWeight.w500,
    // ),
    // labelSmall: TextStyle(
    //   fontSize: 10,
    //   fontWeight: FontWeight.w400,
    // ),
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
      textTheme: lightTextTheme,
      colorScheme: const ColorScheme.light().copyWith(
          primary: AppColor.primaryColor,
          surface: AppColor.surfaceColor,
          onSurface: AppColor.onSurfaceColor,
          surfaceTint: Colors.transparent),
      appBarTheme: const AppBarTheme(
        color: AppColor.surfaceColor,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all<Color>(
            AppColor.onSurfaceColor,
          ),
          textStyle: WidgetStateProperty.all<TextStyle>(
            const TextStyle(
              // fontSize: Sizes.p12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all<Color>(
            AppColor.onSurfaceColor,
          ),
        ),
      ),
      iconTheme: const IconThemeData.fallback().copyWith(
        color: AppColor.onSurfaceColor,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        checkColor: WidgetStateProperty.resolveWith(
          (states) => AppColor.primaryColor,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => const BorderSide(
            color: AppColor.primaryColor,
            width: Sizes.p2,
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme().copyWith(
        fillColor: const Color(0xFFF4F4F4),
        filled: true,
        constraints: const BoxConstraints(maxWidth: 179, maxHeight: 59.21),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColor.textFieldBorderColor, width: Sizes.p2),
          borderRadius: BorderRadius.all(
            Radius.circular(Sizes.p10),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColor.textFieldBorderColor, width: Sizes.p2),
            borderRadius: BorderRadius.all(
              Radius.circular(Sizes.p10),
            )),
        disabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColor.textFieldBorderColor, width: Sizes.p2),
            borderRadius: BorderRadius.all(
              Radius.circular(Sizes.p10),
            )),
        errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColor.textFieldBorderColor, width: Sizes.p2),
            borderRadius: BorderRadius.all(
              Radius.circular(Sizes.p10),
            )),
        focusedErrorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColor.textFieldBorderColor, width: Sizes.p2),
            borderRadius: BorderRadius.all(
              Radius.circular(Sizes.p10),
            )),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateColor.resolveWith(
          (states) {
            return AppColor.primaryColor;
          },
        ),
      ),
    );

    // checkboxTheme: CheckboxThemeData(
    //   fillColor: WidgetStateColor.resolveWith(
    //     (states) {
    //       return Colors.black;
    //     },
    //   ),
    // ),
    // floatingActionButtonTheme: const FloatingActionButtonThemeData(
    //   foregroundColor: Color(0xFFF8C630),
    //   backgroundColor: Colors.black,
    // ),
    // elevatedButtonTheme: ElevatedButtonThemeData(
    //   style: ButtonStyle(
    //     shape: WidgetStateProperty.all<RoundedRectangleBorder>(
    //       RoundedRectangleBorder(
    //         borderRadius: BorderRadius.circular(18.0),
    //       ),
    //     ),
    //     backgroundColor: WidgetStateProperty.all<Color>(const Color(0xFF12DE26)),
    //     foregroundColor: WidgetStateProperty.all<Color>(const Color(0xFFFFFFFF)),
    //   ),
    // ),
    // dialogTheme: const DialogTheme(
    //   surfaceTintColor: AppColor.primaryColor,
    // ),
    // cardTheme: CardTheme(
    //   elevation: 0,
    //   surfaceTintColor: AppColor.primaryColor,
    //   color: const Color(0xFFF4F4F4),
    //   shape: OutlineInputBorder(
    //     borderRadius: BorderRadius.circular(5),
    //     borderSide: BorderSide.none,
    //   ),
    // ),
    // navigationRailTheme: const NavigationRailThemeData(
    //   useIndicator: false,
    //   backgroundColor: AppColor.primaryColor,
    // ),
    // filledButtonTheme: FilledButtonThemeData(
    //   style: FilledButton.styleFrom(
    //     // foregroundColor: Colors.white,
    //     shape: RoundedRectangleBorder(
    //       borderRadius: BorderRadius.circular(Sizes.p5),
    //     ),
    //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    //     fixedSize: const Size(48, 43),
    //   ),
    // )
  }

//   static ThemeData dark() {
//     return ThemeData(
//       visualDensity: VisualDensity.adaptivePlatformDensity,
//       useMaterial3: true,
//       checkboxTheme: CheckboxThemeData(
//         fillColor: WidgetStateColor.resolveWith(
//           (states) {
//             return Colors.black;
//           },
//         ),
//       ),
//       floatingActionButtonTheme:
//           const FloatingActionButtonThemeData(foregroundColor: Colors.white, backgroundColor: AppColor.primaryColor),
//       textTheme: darkTextTheme,
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ButtonStyle(
//           shape: WidgetStateProperty.all<RoundedRectangleBorder>(
//             RoundedRectangleBorder(
//               side: const BorderSide(
//                 width: 1,
//                 color: Color(0xFF707070),
//               ),
//               borderRadius: BorderRadius.circular(Sizes.p3),
//             ),
//           ),
//           backgroundColor: WidgetStateProperty.all<Color>(const Color(0xFF2F2F2F)),
//           foregroundColor: WidgetStateProperty.all<Color>(const Color(0xFF707070)),
//         ),
//       ),
//       cardTheme: CardTheme(
//         elevation: 0,
//         surfaceTintColor: AppColor.primaryColor,
//         color: const Color(0xFFF4F4F4),
//         shape: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(5),
//           borderSide: BorderSide.none,
//         ),
//       ),
//       navigationRailTheme: const NavigationRailThemeData(
//         useIndicator: false,
//         backgroundColor: AppColor.primaryColor,
//       ),
//       appBarTheme:
//           const AppBarTheme(backgroundColor: AppColor.primaryColor, systemOverlayStyle: SystemUiOverlayStyle.light),
//     );
//   }
}
