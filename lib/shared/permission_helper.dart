import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<void> requestAllRequiredPermissions() async {
    // We request a batch of critical permissions. 
    // Location Always is especially needed for continuous background GPS tracking.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.locationAlways,
      Permission.camera,
      Permission.microphone,
      Permission.notification,
    ].request();

    // Optionally handle denied statuses here
    print('Permissions requested: $statuses');
  }
}
