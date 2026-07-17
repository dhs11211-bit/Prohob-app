import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'camera_capture_modal.dart';
import 'recurring_series_modal.dart';

class JobDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> jobData;
  final Map<String, Map<String, dynamic>> allProfiles;
  final Map<String, Color> allColors;
  final String timeStr;
  final VoidCallback onChatPressed;
  final VoidCallback onDirectionsPressed;
  final VoidCallback onCallPressed;
  final bool showGenerateInvoice;
  final VoidCallback? onGenerateInvoicePressed;

  const JobDetailsScreen({
    Key? key,
    required this.jobData,
    required this.allProfiles,
    required this.allColors,
    required this.timeStr,
    required this.onChatPressed,
    required this.onDirectionsPressed,
    required this.onCallPressed,
    this.showGenerateInvoice = false,
    this.onGenerateInvoicePressed,
  }) : super(key: key);

  Widget _buildUserRow(dynamic u, Map<String, Color> allColors) {
    final name = u is Map ? (u['name'] ?? u['display_name'] ?? 'Worker') : 'Worker';
    final roleName = u is Map ? (u['role_name'] ?? u['role'] ?? 'Worker') : 'Worker';
    final id = u is Map ? u['id']?.toString() ?? '' : '';
    final Color dotColor = allColors[id] ?? const Color(0xFF3B82F6);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: dotColor.withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'W',
              style: TextStyle(
                color: dotColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  roleName,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF0D1B2A);
    const Color card = Color(0xFF1E293B);
    const Color text = Colors.white;
    const Color muted = Colors.white60;
    const Color accentBlue = Color(0xFF3B82F6);
    const Color neonAction = Color(0xFF00FFCC);
    const Color accentRed = Color(0xFFEF4444);

    String status = (jobData['job_status'] ?? jobData['status'] ?? 'SCHEDULED').toString().toUpperCase();
    Color statusColor = accentBlue;
    if (status == 'ACTIVE' || status == 'IN PROGRESS') statusColor = const Color(0xFF10B981);
    if (status == 'PENDING' || status == 'DRAFT') statusColor = const Color(0xFFF59E0B);
    if (status == 'COMPLETED') statusColor = const Color(0xFF8B5CF6);

    final String displayNo = jobData['job_number'] ?? "#${jobData['id']}";
    final String jobTitle = "$displayNo - ${jobData['title'] ?? 'Job Title'}";
    final String customerName = jobData['customer_name'] ?? 'Unknown Customer';
    final String address = jobData['address'] ?? 'No address provided';
    final String description = (jobData['description'] == null || jobData['description'].toString().isEmpty)
        ? ((jobData['notes'] == null || jobData['notes'].toString().isEmpty) ? 'No notes provided.' : jobData['notes'])
        : jobData['description'].toString();

    bool isTemplate = jobData['is_template'] == 1 || jobData['is_template'] == true;
    bool isInstance = jobData['recurring_parent_id'] != null;
    List<dynamic> tasks = jobData['tasks'] ?? [];

    // Parse Job Date
    DateTime? jobDate;
    if (jobData['start_date'] != null) {
      jobDate = DateTime.tryParse(jobData['start_date'].toString());
    }
    if (jobDate == null && jobData['scheduled_time'] != null) {
      jobDate = DateTime.tryParse(jobData['scheduled_time'].toString());
    }
    String dateStr = jobDate != null ? DateFormat('EEEE, MMMM d, yyyy').format(jobDate) : 'Date not set';

    // Parse and group assigned staff vs team
    List<dynamic> assignedUsers = [];
    if (jobData['assigned_users'] is List) {
      assignedUsers = List.from(jobData['assigned_users']);
    }
    
    if (assignedUsers.isEmpty && jobData['assigned_workers'] is List) {
      final workersList = jobData['assigned_workers'] as List<dynamic>;
      for (var wId in workersList) {
        var profile = allProfiles[wId.toString()];
        if (profile != null) {
          assignedUsers.add({
            'id': wId,
            'name': profile['display_name'] ?? profile['name'] ?? 'Crew Member',
            'photo': profile['photo_url'] ?? profile['photo'],
            'role_slug': profile['role_slug'] ?? (profile['role']?.toString().toLowerCase() ?? 'worker'),
            'role_name': profile['role'] ?? 'Worker',
          });
        } else {
          assignedUsers.add({
            'id': wId,
            'name': 'Crew Member',
            'photo': null,
            'role_slug': 'worker',
            'role_name': 'Worker',
          });
        }
      }
    }

    // Split: team assignments (has team_name) vs individual staff (no team_name)
    Map<String, List<dynamic>> groupedTeams = {};
    for (var u in assignedUsers) {
      if (u is Map) {
        final teamName = u['team_name']?.toString() ?? u['team']?.toString();
        if (teamName != null && teamName.isNotEmpty) {
          groupedTeams.putIfAbsent(teamName, () => []).add(u);
        }
      }
    }

    List<dynamic> staffList = assignedUsers.where((u) {
      if (u is Map) {
        final teamName = u['team_name']?.toString() ?? u['team']?.toString();
        return teamName == null || teamName.isEmpty;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Job Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CameraCaptureModal(
              initialJobId: jobData['id'],
              initialCustomerId: jobData['customer_id'],
              // Invoice could be determined if job has one, or user selects invoice
            ),
          );
        },
        backgroundColor: accentBlue,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Client Name
                  Text(
                    jobTitle,
                    style: const TextStyle(
                      color: text,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    customerName,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Job Date below Customer Name
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: muted),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Job Scheduled Time below Date
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: muted),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tags Row: Recurring on Left, Status on Right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           if (isTemplate)
                             GestureDetector(
                               onTap: () {
                                 showModalBottomSheet(
                                   context: context,
                                   isScrollControlled: true,
                                   backgroundColor: Colors.transparent,
                                   builder: (context) => RecurringSeriesModal(
                                     parentJobId: jobData['id'],
                                   ),
                                 );
                               },
                               child: Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                 decoration: BoxDecoration(
                                   color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                   borderRadius: BorderRadius.circular(12),
                                   border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                                 ),
                                 child: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     const Icon(Icons.autorenew, size: 14, color: Color(0xFF8B5CF6)),
                                     const SizedBox(width: 6),
                                     const Text(
                                       "View Series Dashboard",
                                       style: TextStyle(
                                         color: Color(0xFF8B5CF6),
                                         fontSize: 12,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                             )
                           else if (isInstance)
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: const Color(0xFFF59E0B).withOpacity(0.15),
                                 borderRadius: BorderRadius.circular(12),
                                 border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                               ),
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   const Icon(Icons.copy, size: 14, color: Color(0xFFF59E0B)),
                                   const SizedBox(width: 6),
                                   Text(
                                     "Instance #${jobData['recurring_instance'] ?? '?'}",
                                     style: const TextStyle(
                                       color: Color(0xFFF59E0B),
                                       fontSize: 12,
                                       fontWeight: FontWeight.bold,
                                     ),
                                   ),
                                 ],
                               ),
                             )
                           else
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: const Color(0xFF3B82F6).withOpacity(0.15),
                                 borderRadius: BorderRadius.circular(12),
                                 border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                               ),
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   const Icon(Icons.looks_one, size: 14, color: Color(0xFF3B82F6)),
                                   const SizedBox(width: 6),
                                   const Text(
                                     "Single Job",
                                     style: TextStyle(
                                       color: Color(0xFF3B82F6),
                                       fontSize: 12,
                                       fontWeight: FontWeight.bold,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Location Card
                  const Text(
                    "LOCATION",
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: accentBlue, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              color: text,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Job Description / Notes
                  const Text(
                    "JOB DESCRIPTION",
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      description,
                      style: const TextStyle(
                        color: text,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tasks Checklist (if any)
                  if (tasks.isNotEmpty) ...[
                    const Text(
                      "TASK CHECKLIST",
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...tasks.map((t) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: accentBlue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.toString(),
                              style: const TextStyle(
                                color: text,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        ],
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Assigned Staff Section
                  const Text(
                    "ASSIGNED STAFF",
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (staffList.isEmpty)
                    const Text(
                      "No staff assigned.",
                      style: TextStyle(color: muted, fontSize: 14),
                    )
                  else
                    ...staffList.map((u) => _buildUserRow(u, allColors)),
                  const SizedBox(height: 24),

                  // Assigned Team Section
                  const Text(
                    "ASSIGNED TEAM",
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (groupedTeams.isEmpty)
                    const Text(
                      "No team assigned.",
                      style: TextStyle(color: muted, fontSize: 14),
                    )
                  else
                    ...groupedTeams.entries.expand((entry) => [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            color: accentBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...entry.value.map((u) => _buildUserRow(u, allColors)),
                    ]),
                  const SizedBox(height: 24),

                  // Generate Invoice (Admin Completed)
                  if (showGenerateInvoice && onGenerateInvoicePressed != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: onGenerateInvoicePressed,
                        child: const Text(
                          'Generate Invoice',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Bottom Actions Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // CHAT (First, Left) styled transparent like others
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: neonAction.withOpacity(0.5)),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble, color: neonAction, size: 18),
                        label: const Text(
                          'CHAT',
                          style: TextStyle(color: neonAction, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onChatPressed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // CALL (Middle)
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5)),
                          ),
                        ),
                        icon: const Icon(Icons.phone, color: Color(0xFF10B981), size: 18),
                        label: const Text(
                          'CALL',
                          style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                        ),
                        onPressed: onCallPressed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // MAPS (Right)
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: accentBlue.withOpacity(0.5)),
                          ),
                        ),
                        icon: const Icon(Icons.navigation, color: accentBlue, size: 18),
                        label: const Text(
                          'MAPS',
                          style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onDirectionsPressed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
