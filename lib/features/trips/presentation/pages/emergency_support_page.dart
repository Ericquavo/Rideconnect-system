import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencySupportPage extends StatelessWidget {
  const EmergencySupportPage({super.key, required this.tripId});

  final int tripId;

  Future<void> _callSupport() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(
              Icons.emergency_rounded,
              color: Color(0xFFFF5E5B),
            ),
            title: const Text('Trip emergency'),
            subtitle: Text('Trip #$tripId is attached to this support action.'),
          ),
          ElevatedButton.icon(
            onPressed: _callSupport,
            icon: const Icon(Icons.call_rounded),
            label: const Text('Call emergency line'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chat_rounded),
            label: const Text('Return to trip chat'),
          ),
        ],
      ),
    );
  }
}
