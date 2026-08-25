import '/auth/laravel_auth_manager.dart';

class AuthHelpers {
  static Map<String, dynamic>? get userData {
    final user = currentUser as LaravelAuthUser?;
    return user?.userData;
  }

  static String get roleSlug {
    final data = userData;
    return (data?['role']?['slug'] ?? 'staff').toString().toLowerCase();
  }

  static bool get isAdmin {
    final slug = roleSlug;
    return slug == 'admin' ||
        slug == 'super_admin' ||
        slug == 'super-admin' ||
        slug == 'manager';
  }

  static List<String> get permissions {
    final data = userData;
    final permsRaw = data?['role']?['permissions'];
    if (permsRaw is List) {
      return permsRaw
          .map((p) {
            if (p is Map) return (p['name'] ?? p['slug'] ?? '').toString();
            return p.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  static bool hasPermission(String permissionName) {
    if (isAdmin) return true;
    final target = permissionName.trim().toLowerCase();
    return permissions.any((p) => p.trim().toLowerCase() == target);
  }
}
