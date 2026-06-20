import 'package:flutter/material.dart';

/// Central home for app-wide constants.
class AppConstants {
  AppConstants._();

  static const String kSystemAUrl = 'http://10.0.2.2:3001';
  static const String kSystemBUrl = 'http://10.0.2.2:3002';

  static const Color kPrimary = Color(0xFF21455F);
  static const Color kPrimaryDark = Color(0xFF132B3E);
  static const Color kPrimaryHover = Color(0xFF2D5C7C);
  static const Color kAccent = Color(0xFFD97A28);
  static const Color kAccentSoft = Color(0xFFFFE8CF);
  static const Color kSurface = Color(0xFFF4F1EB);
  static const Color kCard = Color(0xFFFFFFFF);
  static const Color kBorder = Color(0xFFE2DDD4);
  static const Color kMutedText = Color(0xFF66737E);
  static const Color kSuccess = Color(0xFF2C7A52);
  static const Color kDanger = Color(0xFFB44C45);
  static const Color kInfo = Color(0xFF3D6D9A);

  static const String kCurrency = 'EGP';

  /// Supported prerequisite file extensions for the upload workflow.
  static const Set<String> kSupportedUploadExtensions = {
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'heic',
    'heif',
    'svg',
    'bmp',
    'img',
    'doc',
    'docx',
    'txt',
    'zip',
    'rar',
    'psd',
    'ai',
    'xd',
    'fig',
  };
}
