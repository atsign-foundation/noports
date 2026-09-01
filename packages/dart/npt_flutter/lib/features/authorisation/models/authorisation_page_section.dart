import 'package:flutter/material.dart';

enum AuthorisationPageSection {
  requests('Requests', Icons.question_mark_outlined),
  otp('OTP', Icons.numbers),
  setPin('Set pin', Icons.dialpad),
  approvedEnrollments('Approved Enrollments', Icons.done_all);

  const AuthorisationPageSection(this.title, this.icon);

  final String title;
  final IconData icon;
}
