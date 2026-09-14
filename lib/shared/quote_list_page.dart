import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '/backend/api_service.dart';
import 'quote_detail_screen.dart';
import 'create_quote_screen.dart';
import '/shared/toast_service.dart';

class QuoteListPage extends StatefulWidget {
  const QuoteListPage({Key? key}) : super(key: key);

  @override
  State<QuoteListPage> createState() => _QuoteListPageState();
}

class _QuoteListPageState extends State<QuoteListPage> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color cardBorder = const Color(0xFF334155);
  final Color textWhite = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color purple = const Color(0xFF8B5CF6);
  final Color neonAction = const Color(0xFFD4FF00);
  final Color accentGreen = const Color(0xFF10B981);
  final Color accentAmber = const Color(0xFFF59E0B);
  final Color accentRed = const Color(0xFFEF4444);

  List<dynamic> _quotes = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Search & Filter
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatus = 'all';

  // KPI Stats
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;

  final ScrollController _listScrollController = ScrollController();

  final List<Map<String, String>> _statusFilters = const [
    {'key': 'all', 'label': 'All'},
    {'key': 'draft', 'label': 'Draft'},
    {'key': 'sent', 'label': 'Sent'},
    {'key': 'viewed', 'label': 'Viewed'},
    {'key': 'accepted', 'label': 'Accepted'},
    {'key': 'converted', 'label': 'Converted'},
    {'key': 'declined', 'label': 'Declined'},
    {'key': 'expired', 'label': 'Expired'},
  ];

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_onScroll);
    _fetchStats();
    _fetchQuotes(reset: true);
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_listScrollController.hasClients) return;
    final pos = _listScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 && !_isLoadingMore && _hasMore) {
      _fetchQuotes(loadMore: true);
    }
  }

  Future<void> _fetchStats() async {
    try {
      final res = await ApiService.instance.request(
        method: 'GET',
        endpoint: '/quotes/stats',
      );
      if (mounted) {
        setState(() {
          _stats = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching quote stats: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _fetchQuotes({bool reset = false, bool loadMore = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
      });
    } else if (loadMore) {
      if (!_hasMore || _isLoadingMore || _isLoading) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final queryParams = <String, dynamic>{
        'limit': 15,
        'page': _currentPage,
      };

      if (_selectedStatus != 'all') {
        queryParams['status'] = _selectedStatus;
      }
      if (_searchCtrl.text.trim().isNotEmpty) {
        queryParams['search'] = _searchCtrl.text.trim();
      }

      final res = await ApiService.instance.request(
        method: 'GET',
        endpoint: '/quotes',
        queryParams: queryParams,
      );

      List<dynamic> fetched = [];
      int currentPage = 1;
      int lastPage = 1;

      // Safe extraction handling unwrapped or wrapped pagination
      final dynamic rawData = res['data'];
      if (rawData is List) {
        fetched = rawData;
        currentPage = res['current_page'] is int ? res['current_page'] : 1;
        lastPage = res['last_page'] is int ? res['last_page'] : 1;
      } else if (rawData is Map && rawData['data'] is List) {
        fetched = rawData['data'];
        currentPage = rawData['current_page'] is int ? rawData['current_page'] : 1;
        lastPage = rawData['last_page'] is int ? rawData['last_page'] : 1;
      }

      if (mounted) {
        setState(() {
          if (reset) {
            _quotes = fetched;
          } else {
            _quotes.addAll(fetched);
          }

          _hasMore = currentPage < lastPage;
          if (_hasMore) {
            _currentPage++;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching quotes: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return accentGreen;
      case 'converted':
        return const Color(0xFF10B981);
      case 'declined':
        return accentRed;
      case 'sent':
        return accentBlue;
      case 'viewed':
        return purple;
      case 'expired':
        return accentAmber;
      default:
        return muted;
    }
  }

  Widget _buildKpiBar() {
    if (_isLoadingStats) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }

    final totalCount = _stats?['total'] ?? 0;
    final totalValue = double.tryParse(_stats?['total_value']?.toString() ?? '0') ?? 0;
    final acceptedCount = (_stats?['accepted'] ?? 0) + (_stats?['converted'] ?? 0);
    final acceptedValue = double.tryParse(_stats?['accepted_value']?.toString() ?? '0') ?? 0;
    final pendingCount = (_stats?['sent'] ?? 0) + (_stats?['viewed'] ?? 0);
    final declinedCount = (_stats?['declined'] ?? 0) + (_stats?['expired'] ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Total Estimates',
                  '$totalCount',
                  NumberFormat.compactSimpleCurrency(locale: 'en_US').format(totalValue),
                  accentBlue,
                  Icons.request_quote_rounded,
                  onTap: () {
                    setState(() => _selectedStatus = 'all');
                    _fetchQuotes(reset: true);
                  },
                  isSelected: _selectedStatus == 'all',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  'Accepted / Won',
                  '$acceptedCount',
                  NumberFormat.compactSimpleCurrency(locale: 'en_US').format(acceptedValue),
                  accentGreen,
                  Icons.check_circle_outline_rounded,
                  onTap: () {
                    setState(() => _selectedStatus = 'accepted');
                    _fetchQuotes(reset: true);
                  },
                  isSelected: _selectedStatus == 'accepted',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Pending Review',
                  '$pendingCount',
                  'In Customer Hands',
                  purple,
                  Icons.hourglass_top_rounded,
                  onTap: () {
                    setState(() => _selectedStatus = 'sent');
                    _fetchQuotes(reset: true);
                  },
                  isSelected: _selectedStatus == 'sent',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  'Declined / Expired',
                  '$declinedCount',
                  'Requires Follow-up',
                  accentAmber,
                  Icons.cancel_outlined,
                  onTap: () {
                    setState(() => _selectedStatus = 'declined');
                    _fetchQuotes(reset: true);
                  },
                  isSelected: _selectedStatus == 'declined',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    String count,
    String subtext,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? neonAction : color.withOpacity(0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? neonAction : muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 14, color: isSelected ? neonAction : color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(color: textWhite, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtext,
              style: TextStyle(
                color: isSelected ? Colors.white70 : color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by estimate #, title, or customer...',
            hintStyle: TextStyle(color: muted, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: muted, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: muted, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _fetchQuotes(reset: true);
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onSubmitted: (_) => _fetchQuotes(reset: true),
        ),
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    final secondaryKeys = ['viewed', 'converted', 'declined', 'expired'];
    final isSecondaryActive = secondaryKeys.contains(_selectedStatus);
    final secondaryLabel = isSecondaryActive
        ? _statusFilters.firstWhere((f) => f['key'] == _selectedStatus)['label']!
        : 'More';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildFilterPill('all', 'All')),
          const SizedBox(width: 5),
          Expanded(child: _buildFilterPill('draft', 'Draft')),
          const SizedBox(width: 5),
          Expanded(child: _buildFilterPill('sent', 'Sent')),
          const SizedBox(width: 5),
          Expanded(child: _buildFilterPill('accepted', 'Accepted')),
          const SizedBox(width: 5),
          Expanded(
            child: GestureDetector(
              onTap: _showMoreStatusFiltersSheet,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSecondaryActive ? neonAction : card,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: isSecondaryActive ? neonAction : cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          secondaryLabel,
                          style: TextStyle(
                            color: isSecondaryActive ? Colors.black : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: isSecondaryActive ? Colors.black : muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String key, String label) {
    final isSelected = _selectedStatus == key;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedStatus = key);
        _fetchQuotes(reset: true);
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? neonAction : card,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: isSelected ? neonAction : cardBorder,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  void _showMoreStatusFiltersSheet() {
    final secondaryKeys = ['viewed', 'converted', 'declined', 'expired'];
    final secondaryFilters = _statusFilters.where(
      (sf) => secondaryKeys.contains(sf['key']),
    ).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'More Status Filters',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...secondaryFilters.map((sf) {
                final isSelected = _selectedStatus == sf['key'];
                final count = _stats?[sf['key']] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? neonAction.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? neonAction : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(sf['key']!),
                      ),
                    ),
                    title: Text(
                      sf['label']!,
                      style: TextStyle(
                        color: isSelected ? neonAction : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle_rounded, color: neonAction, size: 18),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedStatus = sf['key']!);
                      _fetchQuotes(reset: true);
                    },
                  ),
                );
              }),
              if (secondaryKeys.contains(_selectedStatus)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.clear, size: 16, color: muted),
                    label: Text('Reset to All', style: TextStyle(color: muted)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedStatus = 'all');
                      _fetchQuotes(reset: true);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteCard(Map<String, dynamic> quote) {
    final status = quote['status'] ?? 'draft';
    final qNumber = quote['quote_number'] ?? '';
    final title = quote['title'] ?? 'Estimate';
    final total = double.tryParse(quote['total']?.toString() ?? '0') ?? 0.0;
    
    final customerObj = quote['customer'];
    String customerName = 'Unknown Customer';
    if (customerObj != null) {
      final fn = customerObj['first_name'] ?? '';
      final ln = customerObj['last_name'] ?? '';
      final name = '$fn $ln'.trim();
      final company = customerObj['company_name'];
      if (company != null && company.toString().isNotEmpty) {
        customerName = name.isNotEmpty ? '$name ($company)' : company.toString();
      } else if (name.isNotEmpty) {
        customerName = name;
      } else if (customerObj['name'] != null) {
        customerName = customerObj['name'];
      }
    }

    final issueDate = quote['issue_date'] != null 
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(quote['issue_date'])) 
        : '';
    final expiryDate = quote['expiry_date'] != null 
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(quote['expiry_date'])) 
        : null;

    final deposit = double.tryParse(quote['deposit_required']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuoteDetailScreen(quoteId: quote['id']),
          ),
        );
        _fetchStats();
        _fetchQuotes(reset: true);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Number, Copy, Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      qNumber,
                      style: TextStyle(
                        color: accentBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: 14, color: muted),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy Estimate #',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qNumber));
                        ToastService.info(context, 'Estimate # copied');
                      },
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(status).withOpacity(0.4)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title & Customer
            Text(
              title,
              style: TextStyle(
                color: textWhite,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    customerName,
                    style: TextStyle(color: muted, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Financials & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      issueDate,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    if (expiryDate != null) ...[
                      Text(' • Exp: $expiryDate', style: TextStyle(color: muted.withOpacity(0.7), fontSize: 11)),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat.currency(symbol: '\$').format(total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (deposit > 0)
                      Text(
                        'Dep: ${NumberFormat.compactSimpleCurrency(locale: 'en_US').format(deposit)}',
                        style: TextStyle(color: accentBlue, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Estimates & Quotes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () {
              _fetchStats();
              _fetchQuotes(reset: true);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: neonAction,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Create Estimate', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateQuoteScreen()),
          );
          if (created == true) {
            _fetchStats();
            _fetchQuotes(reset: true);
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _fetchStats(),
            _fetchQuotes(reset: true),
          ]);
        },
        color: neonAction,
        backgroundColor: card,
        child: ListView(
          controller: _listScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          children: [
            // KPI Summary Cards
            _buildKpiBar(),
            const SizedBox(height: 16),

            // Live Search Bar
            _buildSearchBar(),
            const SizedBox(height: 12),

            // Status Filter Chips
            _buildStatusFilterChips(),
            const SizedBox(height: 16),

            // Quote Cards List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: Colors.white24)),
                    )
                  : _quotes.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.request_quote_outlined, size: 48, color: muted),
                              const SizedBox(height: 12),
                              const Text(
                                'No quotes found.',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedStatus != 'all'
                                    ? 'No quotes matching "${_selectedStatus.toUpperCase()}" status.'
                                    : 'Create your first estimate to get started.',
                                style: TextStyle(color: muted, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final created = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CreateQuoteScreen()),
                                  );
                                  if (created == true) {
                                    _fetchStats();
                                    _fetchQuotes(reset: true);
                                  }
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('New Estimate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentBlue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            ..._quotes.map((q) => _buildQuoteCard(q)),
                            if (_isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator(color: Colors.white24)),
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
