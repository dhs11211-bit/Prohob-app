import 'package:flutter/material.dart';
import '../custom_code/widgets/index.dart' as custom_widgets;

class AdminMoreTab extends StatefulWidget {
  const AdminMoreTab({Key? key}) : super(key: key);

  @override
  State<AdminMoreTab> createState() => _AdminMoreTabState();
}

class _AdminMoreTabState extends State<AdminMoreTab> {
  String? _activeSection; // null = grid menu, 'team', 'customers', 'map'

  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color textWhite = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    if (_activeSection == 'team') {
      return _buildSubSection(
        title: 'Team Management',
        child: custom_widgets.AdminTeamWidge(
          width: double.infinity,
          height: double.infinity,
          onLogout: () async {},
          onChatWithWorker: (workerId, workerName) async {},
          onChatTap: (chatId, chatName) async {},
        ),
      );
    }

    if (_activeSection == 'customers') {
      return _buildSubSection(
        title: 'Customers',
        child: custom_widgets.AdminCustomersView(
          width: double.infinity,
          height: double.infinity,
          onLogout: () async {},
        ),
      );
    }

    if (_activeSection == 'map') {
      return _buildSubSection(
        title: 'Map View',
        child: custom_widgets.UnifiedMapWidget(
          width: double.infinity,
          height: double.infinity,
          onLogout: () async {},
        ),
      );
    }

    return _buildGridMenu();
  }

  Widget _buildSubSection({required String title, required Widget child}) {
    return Container(
      color: bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: card,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                  onPressed: () => setState(() => _activeSection = null),
                ),
                Text(
                  title,
                  style: TextStyle(color: textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildGridMenu() {
    return Container(
      color: bg,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'Admin Suite',
              style: TextStyle(
                color: textWhite,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Access management and administration tools',
              style: TextStyle(color: muted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _menuCard(
                  title: 'Team',
                  subtitle: 'Manage workers & roles',
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => setState(() => _activeSection = 'team'),
                ),
                _menuCard(
                  title: 'Customers',
                  subtitle: 'Client contacts & jobs',
                  icon: Icons.contacts_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => setState(() => _activeSection = 'customers'),
                ),
                _menuCard(
                  title: 'Map View',
                  subtitle: 'Live team locations',
                  icon: Icons.map_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => setState(() => _activeSection = 'map'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        color: textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: muted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
