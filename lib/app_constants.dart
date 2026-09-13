import 'package:flutter/foundation.dart';
import 'backend/api_service.dart';

class AppConstants {
  static const String fallbackGoogleMapsApiKey =
      "AIzaSyCCepBRzPsX3M20vK0YTX5KINtZCiPkvYE";

  static String get apiBaseUrl => ApiService.baseUrl;
}
