import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/backend/api_service.dart';
import 'quote_detail_screen.dart';

class QuoteListPage extends StatefulWidget {
  const QuoteListPage({Key? key}) : super(key: key);

  @override
  State<QuoteListPage> createState() => _QuoteListPageState();
}

class _QuoteListPageState extends State<QuoteListPage> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color textWhite = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color neonAction = const Color(0xFFD4FF00);

  List<dynamic> _quotes = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_onScroll);
    _fetchQuotes(reset: true);
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_listScrollController.hasClients) return;
    final pos = _listScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 && !_isLoadingMore && _hasMore) {
      _fetchQuotes(loadMore: true);
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
      final res = await ApiService.instance.request(
        method: 'GET',
        endpoint: '/quotes',
        queryParams: {
          'limit': 15,
          'page': _currentPage,
        },
      );
      
      final data = res['data'];
      final List<dynamic> fetched = data['data'] ?? [];

      setState(() {
        if (reset) {
          _quotes = fetched;
        } else {
          _quotes.addAll(fetched);
        }
        
        final currentPage = data['current_page'] ?? 1;
        final lastPage = data['last_page'] ?? 1;
        _hasMore = currentPage < lastPage;
        
        if (_hasMore) {
          _currentPage++;
        }
      });
    } catch (e) {
      debugPrint('Error fetching quotes: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'converted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'sent':
      case 'viewed':
        return accentBlue;
      default:
        return muted;
    }
  }

  Widget _buildQuoteCard(Map<String, dynamic> quote) {
    final status = quote['status'] ?? 'draft';
    final qNumber = quote['quote_number'] ?? '';
    final title = quote['title'] ?? 'Estimate';
    final total = double.tryParse(quote['total']?.toString() ?? '0') ?? 0.0;
    
    final customer = quote['customer'] != null ? quote['customer']['name'] : 'Unknown Customer';
    final issueDate = quote['issue_date'] != null ? DateFormat('MMM d, yyyy').format(DateTime.parse(quote['issue_date'])) : '';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuoteDetailScreen(quoteId: quote['id']),
          ),
        );
        _fetchQuotes(reset: true);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  qNumber,
                  style: TextStyle(
                    color: accentBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              customer,
              style: TextStyle(color: muted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: muted),
                    const SizedBox(width: 4),
                    Text(issueDate, style: TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
                Text(
                  NumberFormat.currency(symbol: '\$').format(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
        title: const Text('Quotes & Estimates', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: () => _fetchQuotes(reset: true),
              color: neonAction,
              backgroundColor: card,
              child: _quotes.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'No quotes found.',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _listScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _quotes.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _quotes.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          );
                        }
                        return _buildQuoteCard(_quotes[index]);
                      },
                    ),
            ),
    );
  }
}
