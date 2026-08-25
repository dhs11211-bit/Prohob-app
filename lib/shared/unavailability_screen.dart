import 'package:flutter/material.dart';
import '../backend/api_service.dart';

class UnavailabilityScreen extends StatefulWidget {
  @override
  _UnavailabilityScreenState createState() => _UnavailabilityScreenState();
}

class _UnavailabilityScreenState extends State<UnavailabilityScreen> {
  bool _isLoading = true;
  List<dynamic> _unavailabilities = [];

  @override
  void initState() {
    super.initState();
    _fetchUnavailabilities();
  }

  Future<void> _fetchUnavailabilities() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService.instance.get('/unavailabilities');
      if (response != null && response['status'] == 'success') {
        setState(() {
          _unavailabilities = response['data'] ?? [];
        });
      }
    } catch (e) {
      print('Error fetching unavailabilities: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Off & Blocks'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unavailabilities.isEmpty
              ? const Center(child: Text('No unavailabilities found.'))
              : ListView.builder(
                  itemCount: _unavailabilities.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final item = _unavailabilities[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: ListTile(
                        title: Text(item['reason'] ?? 'Unavailable Block'),
                        subtitle: Text('${item['start_date']} to ${item['end_date']}'),
                        trailing: item['status'] == 1 
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.pending, color: Colors.orange),
                      ),
                    );
                  },
                ),
    );
  }
}
