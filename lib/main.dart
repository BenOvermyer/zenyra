import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenyra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const VaultLoader(),
    );
  }
}

class VaultLoader extends StatefulWidget {
  const VaultLoader({super.key});

  @override
  State<VaultLoader> createState() => _VaultLoaderState();
}

class _VaultLoaderState extends State<VaultLoader> {
  String? _vaultPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVault();
  }

  Future<void> _loadVault() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('vaultPath');
    if (path == null || !(await Directory(path).exists())) {
      setState(() {
        _loading = false;
      });
    } else {
      setState(() {
        _vaultPath = path;
        _loading = false;
      });
    }
  }

  Future<void> _selectVault() async {
    String? selected = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select or Create Vault Folder');
    if (selected != null) {
      await _ensureVaultStructure(selected);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vaultPath', selected);
      setState(() {
        _vaultPath = selected;
      });
    }
  }

  Future<void> _ensureVaultStructure(String path) async {
    final folders = ['archive', 'done', 'inbox', 'recurring', 'by-date'];
    for (final folder in folders) {
      final dir = Directory('$path/$folder');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_vaultPath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Vault Folder')),
        body: Center(
          child: ElevatedButton(
            onPressed: _selectVault,
            child: const Text('Select or Create Vault Folder'),
          ),
        ),
      );
    }
    return TodoHome(vaultPath: _vaultPath!);
  }
}
