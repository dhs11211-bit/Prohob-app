import re

with open(r"D:\Projects\David\Devoted\prohob-app\lib\workers_pag\custom_schedule.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Replace SingleChildScrollView
old_scroll = """            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),"""
new_scroll = """            child: SingleChildScrollView(
              controller: _listScrollController,
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),"""

content = content.replace(old_scroll, new_scroll)

# Now replace the jobs loop section
pattern = r"const SizedBox\(height: 32\),.*?GestureDetector\(\s*onTap: _openAllHolidaysModal,"

new_jobs_section = """const SizedBox(height: 32),
                    // NEW JOBS MAPPING
                    if (_allJobs.isNotEmpty)
                      ...(() {
                        List<Widget> widgets = [];
                        String? lastDateStr;
                        for (var job in _allJobs) {
                          final data = job as Map<String, dynamic>;
                          DateTime jobTime;
                          if (data['scheduled_time'] is String) {
                            jobTime = DateTime.parse(data['scheduled_time']);
                          } else {
                            try { jobTime = DateTime.parse(data['scheduled_time']); }
                            catch (e) { jobTime = DateTime.now(); }
                          }
                          
                          // The group by date logic
                          String currentDateStr = DateFormat('EEEE, MMM d, yyyy').format(jobTime);
                          if (lastDateStr != currentDateStr) {
                            widgets.add(
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      currentDateStr,
                                      style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.bold)
                                    ),
                                    if (lastDateStr == null) // only show time off button on first group
                                      GestureDetector(
                                        onTap: _openTimeOffModal,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(8)),
                                          child: Text('+ Request time off', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.bold))
                                        )
                                      )
                                  ]
                                )
                              )
                            );
                            lastDateStr = currentDateStr;
                          }

                          // Calculate times
                          String timeStr = "Time not set";
                          if (data['scheduled_time'] != null) {
                            try {
                              DateTime parsedTime = DateTime.parse(data['scheduled_time'].toString().trim()).toLocal();
                              String startStr = DateFormat.jm().format(parsedTime);
                              timeStr = startStr;
                              if (data['start_time'] != null && data['start_time'].toString().trim().isNotEmpty) {
                                 try {
                                   DateTime startParsed = DateTime.parse("1970-01-01 " + data['start_time'].toString().trim());
                                   startStr = DateFormat.jm().format(startParsed);
                                   timeStr = startStr;
                                 } catch (e) {}
                              }
                              if (data['end_time'] != null && data['end_time'].toString().trim().isNotEmpty) {
                                 try {
                                   DateTime endParsed = DateTime.parse("1970-01-01 " + data['end_time'].toString().trim());
                                   String endStr = DateFormat.jm().format(endParsed);
                                   timeStr = "$startStr - $endStr";
                                 } catch (e) {}
                              }
                            } catch (e) {}
                          }

                          String status = (data['job_status'] ?? 'SCHEDULED').toString().toUpperCase();
                          Color statusColor = const Color(0xFF3B82F6);
                          if (status == 'ACTIVE' || status == 'IN PROGRESS') statusColor = const Color(0xFF10B981);
                          if (status == 'PENDING' || status == 'DRAFT') statusColor = const Color(0xFFF59E0B);
                          if (status == 'COMPLETED') statusColor = const Color(0xFF8B5CF6);

                          final addr = data['address'] ?? 'No address provided';
                          final customerName = data['customer_name'] ?? data['job_type'] ?? 'Scheduled Job';
                          final displayNo = data['job_number'] ?? "#${data['id']}";

                          widgets.add(
                            GestureDetector(
                              onTap: () => _openJobDetailsModal(data['id'].toString(), data, timeStr, jobTime),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                                  ]
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                                                ),
                                                child: Text(
                                                  displayNo,
                                                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  data['title'] ?? 'Job Title',
                                                  style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.bold),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (data['recurring'] == 1 || data['recurring'] == true || data['is_recurring'] == 1 || data['is_recurring'] == true) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                                                  ),
                                                  child: const Icon(Icons.autorenew, color: Color(0xFF8B5CF6), size: 12),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.person_outline, size: 14, color: Colors.white54),
                                              const SizedBox(width: 4),
                                              Text(customerName, style: TextStyle(color: text.withOpacity(0.9), fontSize: 14)),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.access_time, size: 14, color: Colors.white54),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(timeStr, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Builder(
                                                      builder: (context) {
                                                        bool isRecurring = data['recurring'] == 1 || data['recurring'] == true || data['is_recurring'] == 1 || data['is_recurring'] == true;
                                                        Color badgeColor = isRecurring ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6);
                                                        return Container(
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
                                                              Text(isRecurring ? 'Series Job' : 'Single Job', style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold)),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(Icons.location_on, color: muted, size: 12),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(addr, style: TextStyle(color: muted, fontSize: 12), overflow: TextOverflow.ellipsis),
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
                                                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                                      child: Icon(Icons.chevron_right, color: muted, size: 20),
                                    ),
                                  ]
                                )
                              )
                            )
                          );
                        }
                        return widgets;
                      })()
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                        child: Center(child: Text('No shifts scheduled.', style: TextStyle(color: muted)))
                      ),
                      
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    GestureDetector(
                      onTap: _openAllHolidaysModal,"""

content = re.sub(pattern, new_jobs_section, content, flags=re.DOTALL)

with open(r"D:\Projects\David\Devoted\prohob-app\lib\workers_pag\custom_schedule.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated correctly!")
