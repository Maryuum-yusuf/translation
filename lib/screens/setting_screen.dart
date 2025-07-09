import 'package:flutter/material.dart';
import '../models/translation_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingScreen extends StatefulWidget {
  final List<TranslationItem> settingsItems;
  final Function toggleTheme;
  final bool isDarkMode;
  final Function(double)? onTextSizeChanged;

  const SettingScreen({
    super.key,
    required this.settingsItems,
    required this.toggleTheme,
    required this.isDarkMode,
    this.onTextSizeChanged,
  });

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _showKeyboardAtStartup = false;
  double _textSize = 16.0;
  final List<double> _availableTextSizes = [12, 16, 20, 24, 28, 32];

  @override
  void initState() {
    super.initState();
    _loadKeyboardPreference();
    _loadTextSizePreference();
    _checkKeyboardPreference();
  }

  Future<void> _loadKeyboardPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showKeyboardAtStartup =
          prefs.getBool('show_keyboard_at_startup') ?? false;
    });
  }

  Future<void> _toggleKeyboardAtStartup(bool? value) async {
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_keyboard_at_startup', value);
    setState(() {
      _showKeyboardAtStartup = value;
    });
  }

  Future<void> _checkKeyboardPreference() async {
    final prefs = await SharedPreferences.getInstance();
    bool showKeyboard = prefs.getBool('show_keyboard_at_startup') ?? false;
    if (showKeyboard) {
      FocusScope.of(context).requestFocus(FocusNode());
    }
  }

  Future<void> _loadTextSizePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _textSize = prefs.getDouble('text_size') ?? 16.0;
    });
  }

  Future<void> _saveTextSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_size', size);
    setState(() {
      _textSize = size;
    });
    // Notify the parent widget about the text size change
    if (widget.onTextSizeChanged != null) {
      widget.onTextSizeChanged!(size);
    }
  }

  void _showTextSizeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Text size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _availableTextSizes.map((size) {
              return RadioListTile<double>(
                title: Text(size.toInt().toString()),
                value: size,
                groupValue: _textSize,
                activeColor: Colors.green,
                onChanged: (double? value) async {
                  if (value != null) {
                    await _saveTextSize(value);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              child: const Text('CANCEL', style: TextStyle(color: Colors.green)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // When going back to main screen, ensure keyboard state is properly set
        if (_showKeyboardAtStartup) {
          FocusScope.of(context).requestFocus(FocusNode());
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.settings, size: 35, color: Colors.white),
              SizedBox(width: 8),
              Text('Settings',
                  style: TextStyle(fontSize: 27, color: Colors.white)),
            ],
          ),
          backgroundColor: Colors.blue,
        ),
        body: Column(
          children: [
            Container(
              height: 50,
              width: double.infinity,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 8),
                  Text('Dark Mode',
                      style: TextStyle(
                          fontSize: 20,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                        widget.isDarkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 30,
                        color: Colors.blue),
                    onPressed: () {
                      widget.toggleTheme();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Keyboard",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Show the keyboard at startup',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Checkbox(
                        value: _showKeyboardAtStartup,
                        onChanged: _toggleKeyboardAtStartup,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _showTextSizeDialog,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Text size",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _textSize.toInt().toString(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
