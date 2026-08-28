import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_constants.dart';

class PaystubView extends StatelessWidget {
  final String payrollRunId;
  final String employeeId;
  final String periodString;
  final double netPay;

  const PaystubView({
    Key? key,
    required this.payrollRunId,
    required this.employeeId,
    required this.periodString,
    required this.netPay,
  }) : super(key: key);

  Future<void> _downloadPaystub(BuildContext context) async {
    // API endpoint for downloading paystub pdf
    final String url = '${AppConstants.apiBaseUrl}/payroll/paystub/$payrollRunId/$employeeId';
    final Uri uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch paystub viewer')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay Period: $periodString',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  'Net Pay: \$${netPay.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.download, color: Colors.blue),
              onPressed: () => _downloadPaystub(context),
              tooltip: 'Download Paystub PDF',
            ),
          ],
        ),
      ),
    );
  }
}
