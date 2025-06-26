import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _loadingTheme = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode');
    setState(() {
      if (themeString == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (themeString == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
      _loadingTheme = false;
    });
  }

  Future<void> _setThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    await prefs.setString('themeMode', isDark ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTheme) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return MaterialApp(
      title: 'Zenyra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
      ),
      themeMode: _themeMode,
      home: VaultLoader(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class VaultLoader extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<bool> onThemeModeChanged;
  const VaultLoader({super.key, required this.themeMode, required this.onThemeModeChanged});

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
    return TodoHome(
      vaultPath: _vaultPath!,
      isDarkMode: widget.themeMode == ThemeMode.dark,
      onDarkModeChanged: widget.onThemeModeChanged,
    );
  }
}
