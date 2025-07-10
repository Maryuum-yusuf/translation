import 'package:flutter/material.dart';
import '../models/translation_item.dart';
import 'dart:convert'; // Added for json
import 'package:http/http.dart' as http; // Added for http requests

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<TranslationItem> _allItems = [];
  List<TranslationItem> _filteredItems = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        return item.sourceText.toLowerCase().contains(query) ||
            item.translatedText.toLowerCase().contains(query);
      }).toList();
      // Sort filtered items as well
      _filteredItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  void _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear History'),
          content: const Text('Are you sure you want to clear all history?'),
          actions: [
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      final url = Uri.parse('http://192.168.100.9:5000/history');
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        _fetchHistory(); // Dib u soo celi history-ga cusub
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search history...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : const Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 35,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'History',
                    style: TextStyle(fontSize: 27, color: Colors.white),
                  ),
                ],
              ),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              size: 30,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredItems = _allItems;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 30, color: Colors.white),
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _allItems.isEmpty
                            ? 'No history yet'
                            : 'No results found',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(item.sourceText),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.translatedText),
                            const SizedBox(height: 4),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTimestamp(item.timestamp),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await deleteHistoryItem(item.id);
                                _fetchHistory(); // dib u load garee
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context, item);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<List<TranslationItem>> fetchHistory() async {
    final url = Uri.parse('http://192.168.100.9:5000/history');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      List<TranslationItem> items =
          data.map((item) => TranslationItem.fromJson(item)).toList();
      // Sort: latest first
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    } else {
      throw Exception('Failed to load history');
    }
  }

  Future<void> deleteAllHistory() async {
    final url = Uri.parse('http://192.168.100.9:5000/history');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete all history');
    }
  }

  Future<void> deleteHistoryItem(String id) async {
    final url = Uri.parse('http://192.168.100.9:5000/history/$id');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete history item');
    }
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final items = await fetchHistory();
      setState(() {
        _allItems = items;
        _filteredItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
