// =====================
// TranslationScreen: Main translation logic and stateful widget
// =====================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/translation_item.dart';

class TranslationScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;
  final VoidCallback? openDrawer;
  final double textSize;

  const TranslationScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    this.openDrawer,
    required this.textSize,
  });

  @override
  _TranslationScreenState createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  String selectedLanguage1 = 'Somali';
  String selectedLanguage2 = 'English';
  TextEditingController textController = TextEditingController();
  String translatedText = '';
  bool isFavorite = false;
  late double _textSize;
  final FocusNode _textFieldFocusNode = FocusNode();

  late stt.SpeechToText _speech;
  bool _isListening = false;

  final List<TranslationItem> historyItems = [];
  final List<TranslationItem> favoriteItems = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    textController.addListener(_onTextChanged);
    _textSize = widget.textSize;
    _loadTextSize();
    _checkKeyboardPreference();
  }

  @override
  void didUpdateWidget(covariant TranslationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textSize != oldWidget.textSize) {
      setState(() {
        _textSize = widget.textSize;
      });
    }
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
      _textSize = prefs.getDouble('text_size') ?? widget.textSize;
    });
  }

  @override
  void dispose() {
    _textFieldFocusNode.dispose();
    textController.removeListener(_onTextChanged);
    textController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        translatedText = '';
      });
    }
  }

  Future<void> _translateSpeechText(String text) async {
    if (text.trim().isEmpty) return;
    if (mounted) {
      setState(() {
        translatedText = 'Translating...';
      });
    }
    final url = Uri.parse(
      'https://translate.googleapis.com/translate_a/single?client=gtx&sl=so&tl=en&dt=t&q=${Uri.encodeComponent(text)}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          String translated = '';
          if (data is List && data.isNotEmpty && data[0] is List) {
            final translations = data[0] as List;
            if (translations.isNotEmpty && translations[0] is List) {
              final firstTranslation = translations[0] as List;
              if (firstTranslation.length > 0) {
                translated = firstTranslation[0].toString();
              }
            }
          }
          if (translated.isEmpty) {
            translated = 'Error: No translation received';
          }
          if (mounted) {
            setState(() {
              translatedText = translated;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              translatedText = 'Error: Invalid response format';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            translatedText =
                'Translation failed - Status: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          translatedText = 'Error: $e';
        });
      }
    }
  }

  Future<void> _translateText() async {
    final inputText = textController.text.trim();
    if (inputText.isEmpty) return;
    if (mounted) {
      setState(() {
        translatedText = 'Translating...';
      });
    }
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
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          String idFromServer = '';
          String tempTranslatedText = '';
          if (data != null) {
            if (data is Map) {
              tempTranslatedText = data['translated_text'] ??
                  data['translation'] ??
                  data['result'] ??
                  data['text'] ??
                  data['message'] ??
                  data['content'] ??
                  data['output'] ??
                  data.toString();
              idFromServer = data['id'] ?? data['_id'] ?? '';
            } else if (data is String) {
              tempTranslatedText = data;
            } else {
              tempTranslatedText = data.toString();
            }
          }
          if (tempTranslatedText.isEmpty || tempTranslatedText == 'null') {
            tempTranslatedText = 'Error: Empty translation received';
          }
          if (mounted) {
            setState(() {
              translatedText = tempTranslatedText;
              if (translatedText != 'Error: Empty translation received' &&
                  idFromServer.isNotEmpty) {
                final newItem = TranslationItem(
                  id: idFromServer,
                  sourceText: inputText,
                  translatedText: translatedText,
                  timestamp: DateTime.now(),
                  isFavorite: false,
                );
                historyItems.insert(0, newItem);
                isFavorite = false;
              }
            });
          }
          if (tempTranslatedText != 'Error: Empty translation received' &&
              idFromServer.isNotEmpty) {
            try {
              await saveToHistoryBackend(
                originalText: inputText,
                translatedText: tempTranslatedText,
                isFavorite: false,
              );
            } catch (e) {}
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              translatedText =
                  'Error: Invalid response format. Check console for details.';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            translatedText =
                'Error: Server returned status ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          translatedText = 'Error: Could not connect to server.\n$e';
        });
      }
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

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
          if (textController.text.isNotEmpty) {
            _translateSpeechText(textController.text);
          }
        }
      },
      onError: (val) {
        if (mounted) {
          setState(() => _isListening = false);
        }
        if (!val.toString().contains('timeout')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech recognition error: $val')),
          );
        }
      },
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        localeId: 'so-SO',
        listenMode: stt.ListenMode.dictation,
        onResult: (val) {
          if (mounted) {
            setState(() {
              textController.text = val.recognizedWords;
            });
          }
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  void _handleMicrophonePress() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: LanguageSelector(
          selectedLanguage1: selectedLanguage1,
          selectedLanguage2: selectedLanguage2,
          onSwap: switchLanguages,
          onMenu: widget.openDrawer,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InputSection(
              textController: textController,
              textFieldFocusNode: _textFieldFocusNode,
              isDarkMode: widget.isDarkMode,
              textSize: _textSize,
              isListening: _isListening,
              onCopy: () {
                if (textController.text.isNotEmpty) {
                  _copyToClipboard(textController.text);
                }
              },
              onMic: _handleMicrophonePress,
              onClear: () {
                textController.clear();
              },
              onSend: _translateText,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: OutputSection(
                translatedText: translatedText,
                textSize: _textSize,
                isFavorite: isFavorite,
                onCopy: () {
                  if (translatedText.isNotEmpty) {
                    _copyToClipboard(translatedText);
                  }
                },
                onShare: _shareTranslation,
                onFavorite: _toggleFavorite,
              ),
            ),
          ],
        ),
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

// =====================
// LanguageSelector: Top bar for language swap
// =====================
class LanguageSelector extends StatelessWidget {
  final String selectedLanguage1;
  final String selectedLanguage2;
  final VoidCallback onSwap;
  final VoidCallback? onMenu;
  const LanguageSelector({
    Key? key,
    required this.selectedLanguage1,
    required this.selectedLanguage2,
    required this.onSwap,
    this.onMenu,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return AppBar(
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
            onPressed: onSwap,
          ),
          Text(
            selectedLanguage2,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      elevation: 0,
      leading: onMenu != null
          ? IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: onMenu,
            )
          : null,
    );
  }
}

// =====================
// InputSection: Text input and action buttons
// =====================
class InputSection extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode textFieldFocusNode;
  final bool isDarkMode;
  final double textSize;
  final bool isListening;
  final VoidCallback onCopy;
  final VoidCallback onMic;
  final VoidCallback onClear;
  final Future<void> Function() onSend;
  const InputSection({
    Key? key,
    required this.textController,
    required this.textFieldFocusNode,
    required this.isDarkMode,
    required this.textSize,
    required this.isListening,
    required this.onCopy,
    required this.onMic,
    required this.onClear,
    required this.onSend,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: textController,
          focusNode: textFieldFocusNode,
          style: TextStyle(
            fontSize: textSize,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'type here',
            hintStyle: TextStyle(
              fontSize: textSize,
              color: isDarkMode ? Colors.white70 : Colors.grey,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(16),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
          ),
          maxLines: 6,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 16),
              _buildCircularButton(Icons.copy, onCopy),
              const SizedBox(width: 16),
              _buildCircularButton(isListening ? Icons.stop : Icons.mic, onMic),
              const SizedBox(width: 16),
              _buildCircularButton(Icons.clear, onClear),
              const SizedBox(width: 16),
              _buildCircularButton(Icons.send, onSend),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircularButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

// =====================
// OutputSection: Translation result and action buttons
// =====================
class OutputSection extends StatelessWidget {
  final String translatedText;
  final double textSize;
  final bool isFavorite;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  const OutputSection({
    Key? key,
    required this.translatedText,
    required this.textSize,
    required this.isFavorite,
    required this.onCopy,
    required this.onShare,
    required this.onFavorite,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
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
                  translatedText.isEmpty ? 'Translation' : translatedText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: textSize,
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
                  _buildCircularButton(Icons.copy, onCopy),
                  _buildCircularButton(Icons.share, onShare),
                  _buildCircularButton(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    onFavorite,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
