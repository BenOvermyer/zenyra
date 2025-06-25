import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  final VoidCallback onChooseVault;
  final String currentVault;
  const SettingsView({required this.onChooseVault, required this.currentVault, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Text('Current Vault:', style: TextStyle(fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(currentVault, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose New Vault Directory'),
            onPressed: onChooseVault,
          ),
        ],
      ),
    );
  }
}
