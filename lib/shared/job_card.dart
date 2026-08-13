import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/quick_map_modal.dart';
import 'job_parser.dart';

class SharedJobCard extends StatelessWidget {
  const SharedJobCard({
    Key? key,
    required this.jobData,
    this.onTap,
    this.onEditTap,
  }) : super(key: key);

  final Map<String, dynamic> jobData;
  final VoidCallback? onTap;
  final VoidCallback? onEditTap;

  void _showQuickMap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return QuickMapModal(
          jobData: jobData,
          title: jobData['title'] ?? jobData['customer_name'] ?? 'Job Location',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF1E293B);
    const circleBg = Color(0xFF0F172A);
    const textWhite = Colors.white;
    const muted = Color(0xFF94A3B8);
    const goldPill = Color(0xFFF59E0B);
    const accentBlue = Color(0xFF3B82F6);
    const seriesPurple = Color(0xFF8B5CF6);

    final displayNo = jobData['job_number'] ?? "#${jobData['id']}";
    final title = jobData['title'] ?? 'Job Title';
    final customerName = jobData['customer_name'] ?? jobData['job_type'] ?? 'Scheduled Job';
    final address = jobData['address'] ?? 'No address provided';

    final status = (jobData['job_status'] ?? 'SCHEDULED').toString().toUpperCase();
    Color statusColor = accentBlue;
    if (status == 'ACTIVE' || status == 'IN PROGRESS') statusColor = const Color(0xFF10B981);
    if (status == 'PENDING' || status == 'DRAFT') statusColor = const Color(0xFFF59E0B);
    if (status == 'COMPLETED') statusColor = seriesPurple;

    String timeStr = "Time not set";
    DateTime? jobDate = JobParser.getStartDate(jobData);
    if (jobDate != null) {
      String startStr = DateFormat.jm().format(jobDate);
      timeStr = startStr;
      if (jobData['end_time'] != null && jobData['end_time'].toString().trim().isNotEmpty) {
        try {
          DateTime endParsed = DateTime.parse("1970-01-01 " + jobData['end_time'].toString().trim());
          String endStr = DateFormat.jm().format(endParsed);
          timeStr = "$startStr - $endStr";
        } catch (_) {}
      }
    }

    final isRecurring = JobParser.isRecurring(jobData);
    final badgeColor = isRecurring ? seriesPurple : accentBlue;
    final badgeLabel = isRecurring ? 'Recurring Job' : 'Single Job';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Amber Job Number + Title + Recurring Icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: goldPill.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: goldPill.withOpacity(0.3)),
                        ),
                        child: Text(
                          displayNo,
                          style: const TextStyle(color: goldPill, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecurring) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: seriesPurple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: seriesPurple.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.autorenew, color: seriesPurple, size: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Customer Name & Time
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(customerName, style: const TextStyle(color: textWhite, fontSize: 14)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          timeStr,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 3: Single/Series Job Badge + Location + Status Pill + Map Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: badgeColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isRecurring ? Icons.autorenew : Icons.looks_one, color: badgeColor, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    badgeLabel,
                                    style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.location_on, color: muted, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(color: muted, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Map Navigation Button (Moved here)
                      GestureDetector(
                        onTap: () => _showQuickMap(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: goldPill.withOpacity(0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.map_outlined, color: goldPill, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right Chevron Circle Button
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: circleBg, shape: BoxShape.circle),
              child: const Icon(Icons.chevron_right, color: muted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
