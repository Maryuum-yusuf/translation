import 'package:flutter/material.dart';
import 'package:translation/screens/setting_screen.dart';
import 'screens/favorites_screen.dart';
import 'models/translation_item.dart'; // Ensure this import is present
import 'screens/history_screen.dart'; // Import the HistoryScreen class
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // Add this import for clipboard functionality
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const TranslationApp());
}

class TranslationApp extends StatefulWidget {
  const TranslationApp({super.key});

  @override
  _TranslationAppState createState() => _TranslationAppState();
}

class _TranslationAppState extends State<TranslationApp> {
  bool _isDarkMode = false;

  void toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue,
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primaryColor: Colors.blue,
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: TranslationScreen(
        toggleTheme: toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}

// Remove duplicate TranslationItem definition and use the imported one from models/translation_item.dart

class TranslationScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;

  const TranslationScreen(
      {super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  _TranslationScreenState createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  String selectedLanguage1 = 'Somali';
  String selectedLanguage2 = 'English';
  TextEditingController textController = TextEditingController();
  String translatedText = '';
  bool isFavorite = false;
  double _textSize = 16.0;
  final FocusNode _textFieldFocusNode = FocusNode();

  // Mock data for history and favorites
  final List<TranslationItem> historyItems = [];
  final List<TranslationItem> favoriteItems = [];
  void _navigateToFavorites() async {
    Navigator.pop(context); // Close drawer
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritesScreen(),
      ),
    );
    if (result != null && result is TranslationItem) {
      _setFromItem(result);
    }
  }

  void _navigateToHistory() async {
    Navigator.pop(context); // Close drawer
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryScreen(),
      ),
    );
    if (result != null && result is TranslationItem) {
      _setFromItem(result);
    }
  }

  void _navigateToSettings() {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingScreen(
          settingsItems: const [],
          toggleTheme: widget.toggleTheme,
          isDarkMode: widget.isDarkMode,
          onTextSizeChanged: (double newSize) {
            setState(() {
              _textSize = newSize;
            });
          },
        ),
      ),
    );
  }

  void _setFromItem(TranslationItem item) {
    print('Selected item: \n${item.sourceText} | ${item.translatedText}');
    textController.removeListener(_onTextChanged);
    setState(() {
      textController.text = item.sourceText;
      translatedText = item.translatedText;
    });
    textController.addListener(_onTextChanged);
  }

  @override
  void initState() {
    super.initState();
    textController.addListener(_onTextChanged);
    _loadTextSize();
    _checkKeyboardPreference();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkKeyboardPreference();
  }

  Future<void> _checkKeyboardPreference() async {
    final prefs = await SharedPreferences.getInstance();
    bool showKeyboard = prefs.getBool('show_keyboard_at_startup') ?? false;
    if (showKeyboard && mounted) {
      _textFieldFocusNode.requestFocus();
    }
  }

  Future<void> _loadTextSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _textSize = prefs.getDouble('text_size') ?? 16.0;
    });
  }

  @override
  void dispose() {
    _textFieldFocusNode.dispose();
    textController.removeListener(_onTextChanged);
    textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      // Only update the input text, don't translate
      translatedText = '';
    });
  }

  Future<void> _translateText() async {
    final inputText = textController.text.trim();
    if (inputText.isEmpty) return;

    setState(() {
      translatedText = 'Translating...'; // Show loading state
    });

    final url = Uri.parse('http://192.168.100.9:5000/translate');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': inputText,
          'from_lang': selectedLanguage1,
          'to_lang': selectedLanguage2
        }),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('Decoded data: $data'); // Debug print

          String idFromServer = '';
          String tempTranslatedText = '';
          if (data != null) {
            if (data is Map) {
              tempTranslatedText = data['translated_text'] ??
                  data['translation'] ??
                  data['result'] ??
                  data['text'] ??
                  data.toString();
              idFromServer = data['id'] ?? data['_id'] ?? '';
            } else if (data is String) {
              tempTranslatedText = data;
            } else {
              tempTranslatedText = data.toString();
            }
          }
          if (tempTranslatedText.isEmpty) {
            tempTranslatedText = 'Error: Empty translation received';
          }
          setState(() {
            translatedText = tempTranslatedText;
            if (translatedText != 'Error: Empty translation received' &&
                idFromServer.isNotEmpty) {
              final newItem = TranslationItem(
                id: idFromServer, // ✅ Store the MongoDB ID here
                sourceText: inputText,
                translatedText: translatedText,
                timestamp: DateTime.now(),
                isFavorite: false,
              );
              historyItems.insert(0, newItem);
              isFavorite = false;
            }
          });
          // Save to backend history with both fields (outside setState)
          if (tempTranslatedText != 'Error: Empty translation received' &&
              idFromServer.isNotEmpty) {
            await saveToHistoryBackend(
              originalText: inputText,
              translatedText: tempTranslatedText,
              isFavorite: false,
            );
          }
        } catch (e) {
          print('JSON decode error: $e');
          setState(() {
            translatedText = 'Error: Invalid response format';
          });
        }
      } else {
        setState(() {
          translatedText =
              'Error: Server returned status ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Network error: $e');
      setState(() {
        translatedText = 'Error: Could not connect to server.\n$e';
      });
    }
  }

  void switchLanguages() {
    setState(() {
      String temp = selectedLanguage1;
      selectedLanguage1 = selectedLanguage2;
      selectedLanguage2 = temp;
      _onTextChanged();
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> markAsFavorite(String id) async {
    final url = Uri.parse('http://192.168.100.9:5000/favorite');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id': id}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark as favorite');
    }
  }

  void _toggleFavorite() async {
    if (translatedText.isEmpty) return;

    final match = historyItems.firstWhere(
      (item) =>
          item.sourceText == textController.text &&
          item.translatedText == translatedText &&
          item.id.isNotEmpty,
      orElse: () => TranslationItem(
        id: '',
        sourceText: textController.text,
        translatedText: translatedText,
        timestamp: DateTime.now(),
        isFavorite: true,
      ),
    );

    if (match.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please translate first, then mark as favorite.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      isFavorite = !isFavorite;
    });

    if (isFavorite) {
      await markAsFavorite(match.id);

      setState(() {
        favoriteItems.insert(
          0,
          TranslationItem(
            id: match.id,
            sourceText: match.sourceText,
            translatedText: match.translatedText,
            timestamp: match.timestamp,
            isFavorite: true,
          ),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to favorites'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareTranslation() {
    if (translatedText.isEmpty) return;
    Share.share(translatedText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.translate, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Translation App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: _navigateToFavorites,
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: _navigateToHistory,
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: _navigateToSettings,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share App'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              selectedLanguage1,
              style: const TextStyle(color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              onPressed: switchLanguages,
            ),
            Text(
              selectedLanguage2,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: textController,
              focusNode: _textFieldFocusNode,
              style: TextStyle(
                fontSize: _textSize,
                color: widget.isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'type here',
                hintStyle: TextStyle(
                  fontSize: _textSize,
                  color: widget.isDarkMode ? Colors.white70 : Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
                filled: true,
                fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.white,
              ),
              maxLines: 6,
            ),
            // Buttons under input field
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16),
                  _buildCircularButton(
                    Icons.copy,
                    () {
                      if (textController.text.isNotEmpty) {
                        _copyToClipboard(textController.text);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildCircularButton(
                    Icons.mic_none,
                    () {},
                  ),
                  const SizedBox(width: 16),
                  _buildCircularButton(
                    Icons.volume_up,
                    () {
                      // Toggle dark mode
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildCircularButton(
                    Icons.send,
                    () async {
                      await _translateText();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Translation output container
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            translatedText.isEmpty
                                ? 'Translation'
                                : translatedText,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _textSize,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCircularButton(
                              Icons.copy,
                              () {
                                if (translatedText.isNotEmpty) {
                                  _copyToClipboard(translatedText);
                                }
                              },
                              color: Colors.white,
                            ),
                            _buildCircularButton(
                              Icons.share,
                              _shareTranslation,
                              color: Colors.white,
                            ),
                            _buildCircularButton(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              _toggleFavorite,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton(IconData icon, VoidCallback onPressed,
      {Color? color}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == null ? Colors.blue : Colors.blue.withOpacity(0.2),
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Future<void> saveToHistoryBackend({
    required String originalText,
    required String translatedText,
    required bool isFavorite,
  }) async {
    final url = Uri.parse('http://192.168.100.9:5000/history');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'original_text': originalText,
        'translated_text': translatedText,
        'is_favorite': isFavorite,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save item to backend history');
    }
  }
}
