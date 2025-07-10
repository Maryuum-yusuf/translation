import 'package:flutter/material.dart';
import '../models/translation_item.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:timeago/timeago.dart' as timeago;
// import 'package:http_parser/http_parser.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<TranslationItem> _favorites = [];
  List<TranslationItem> _filteredItems = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
    _searchController.addListener(_onSearchChanged);
  }

  Future<List<TranslationItem>> fetchFavorites() async {
    final url = Uri.parse('http://192.168.100.9:5000/favorites');
    final response = await http.get(url);

    print('Favorites response: ${response.body}'); // Debug

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print('Favorites data length: ${data.length}'); // Debug
      List<TranslationItem> items = [];
      for (var item in data) {
        try {
          final fav = TranslationItem.fromJson(item);
          items.add(fav);
        } catch (e) {
          print('Error parsing favorite: $e, item: $item');
        }
      }
      print('Parsed favorites: ${items.length}');
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    } else {
      throw Exception('Failed to load favorites');
    }
  }

  Future<void> _fetchFavorites() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final items = await fetchFavorites();
      setState(() {
        _favorites = items;
        _filteredItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _favorites.where((item) {
        return item.sourceText.toLowerCase().contains(query) ||
            item.translatedText.toLowerCase().contains(query);
      }).toList();
      _filteredItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Future<void> deleteFavoriteById(String id) async {
    final url = Uri.parse('http://192.168.100.9:5000/favorites/$id');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete favorite');
    }
    _fetchFavorites();
  }

  Future<void> deleteAllFavorites() async {
    final url = Uri.parse('http://192.168.100.9:5000/favorites');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete all favorites');
    }
    _fetchFavorites();
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
                  hintText: 'Search favorites...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : const Row(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 35,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Favorites',
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
                  _filteredItems = _favorites;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 30, color: Colors.white),
            onPressed: deleteAllFavorites,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredItems.isEmpty
              ? Center(
                  child: Text(_favorites.isEmpty
                      ? 'No favorites yet'
                      : 'No results found'),
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
                            Text(
                              timeago.format(item.timestamp),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await deleteFavoriteById(item.id);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
