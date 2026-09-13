import '/auth/laravel_auth_manager.dart';
import '../backend/api_service.dart';

class AuthHelpers {
  static Map<String, dynamic>? get userData {
    final user = currentUser as LaravelAuthUser?;
    return user?.userData;
  }

  static String get roleSlug {
    final data = userData;
    return (data?['role']?['slug'] ?? 'staff').toString().toLowerCase();
  }

  static bool get isSuperAdmin {
    final slug = roleSlug;
    return slug == 'super_admin' || slug == 'super-admin';
  }

  static bool get isAdmin {
    if (isSuperAdmin) return true;
    final slug = roleSlug;
    if (slug == 'admin') return true;
    return permissions.any((p) => p == '*' || p == 'system.admin');
  }

  static List<String> get permissions {
    final data = userData;
    // Phase 12.2: Add user-level permissions JSON
    final userPermsMap = data?['permissions'];
    List<String> combined = [];
    
    final permsRaw = data?['role']?['permissions'];
    if (permsRaw is List) {
      combined.addAll(permsRaw.map((p) {
        if (p is Map) return (p['name'] ?? p['slug'] ?? '').toString();
        return p.toString();
      }).where((s) => s.isNotEmpty));
    }
    
    // Mix in user overrides
    if (userPermsMap is Map) {
      userPermsMap.forEach((key, value) {
        if (value == true) {
          combined.add(key.toString());
        } else if (value == false) {
          combined.removeWhere((p) => p.trim().toLowerCase() == key.toString().toLowerCase());
        }
      });
    }
    
    return combined;
  }

  static bool hasPermission(String permissionName) {
    // Phase 12.2: Direct user-override check
    final data = userData;
    if (data?['permissions'] is Map && data!['permissions'].containsKey(permissionName)) {
      if (data['permissions'][permissionName] == true) return true;
      if (data['permissions'][permissionName] == false) return false;
    }
    
    if (isSuperAdmin) return true;

    final target = permissionName.trim().toLowerCase();
    return permissions.any((p) {
      final perm = p.trim().toLowerCase();
      return perm == '*' || perm == 'system.admin' || perm == target;
    });
  }

  static Map<String, dynamic> mobilePermissions = {};

  static Future<void> fetchMobilePermissions() async {
    try {
      mobilePermissions = await ApiService.instance.getMobilePermissions();
    } catch (_) {}
  }

  static bool hasMobilePermission(String permissionName) {
    if (isAdmin) return true;
    if (mobilePermissions.isEmpty) return true; // Default allow if not fetched
    return mobilePermissions[permissionName] == true;
  }
}
