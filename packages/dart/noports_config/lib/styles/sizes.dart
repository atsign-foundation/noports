import 'package:flutter/material.dart';

/// Spacing scale shared with npt_flutter. Prefer these over literals.
class Sizes {
  static const p2 = 2.0;
  static const p4 = 4.0;
  static const p6 = 6.0;
  static const p8 = 8.0;
  static const p10 = 10.0;
  static const p12 = 12.0;
  static const p14 = 14.0;
  static const p16 = 16.0;
  static const p18 = 18.0;
  static const p20 = 20.0;
  static const p24 = 24.0;
  static const p28 = 28.0;
  static const p32 = 32.0;
  static const p40 = 40.0;
  static const p56 = 56.0;
  static const p240 = 240.0;
  static const p280 = 280.0;
  static const p400 = 400.0;
  static const p520 = 520.0;
  static const p720 = 720.0;
  static const p960 = 960.0;
}

const gapW4 = SizedBox(width: Sizes.p4);
const gapW8 = SizedBox(width: Sizes.p8);
const gapW12 = SizedBox(width: Sizes.p12);
const gapW16 = SizedBox(width: Sizes.p16);
const gapW24 = SizedBox(width: Sizes.p24);

const gapH4 = SizedBox(height: Sizes.p4);
const gapH8 = SizedBox(height: Sizes.p8);
const gapH12 = SizedBox(height: Sizes.p12);
const gapH16 = SizedBox(height: Sizes.p16);
const gapH24 = SizedBox(height: Sizes.p24);
const gapH32 = SizedBox(height: Sizes.p32);

/// Minimum window size; the layout is designed for this and larger.
const kMinWindowSize = Size(920, 620);
