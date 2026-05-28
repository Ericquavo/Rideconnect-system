import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/matching_lifecycle_models.dart';

class AssignmentAttemptsWidget extends StatelessWidget {
  const AssignmentAttemptsWidget({super.key, required this.attempts});

  final List<AssignmentAttempt> attempts;

  @override
  Widget build(BuildContext context) {
    if (attempts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assignment attempts',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...attempts.map(
          (attempt) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 14,
              child: Text('${attempt.index}'),
            ),
            title: Text(
              attempt.driverName.isEmpty
                  ? 'Driver ${attempt.driverId ?? '--'}'
                  : attempt.driverName,
            ),
            subtitle: Text(attempt.status.label),
          ),
        ),
      ],
    );
  }
}
