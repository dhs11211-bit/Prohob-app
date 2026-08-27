import 'package:flutter/material.dart';

class OnboardingBanner extends StatelessWidget {
  final int completionPercentage;
  final String status; // 'pending', 'in_progress', 'under_review', 'approved'
  final List<String> completedSections;
  final VoidCallback onResume;

  const OnboardingBanner({
    Key? key,
    required this.completionPercentage,
    required this.status,
    required this.completedSections,
    required this.onResume,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (status == 'approved') {
      return SizedBox.shrink(); // Hide if approved
    }

    if (status == 'under_review') {
      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.amber.shade700),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your profile is under review. You will be notified once approved to accept jobs.',
                style: TextStyle(color: Colors.amber.shade900),
              ),
            ),
          ],
        ),
      );
    }

    // Pending or In Progress
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_ind, color: Colors.blue.shade700),
              SizedBox(width: 8),
              Text(
                'Complete your setup',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'You must complete your profile before accepting jobs.',
            style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completionPercentage / 100.0,
              minHeight: 8.0,
              backgroundColor: Colors.blue.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '$completionPercentage% Complete',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Resume Onboarding'),
            ),
          ),
        ],
      ),
    );
  }
}
