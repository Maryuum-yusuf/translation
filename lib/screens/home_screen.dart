import 'package:flutter/material.dart';
import 'translation_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'setting_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;
  final double textSize;
  final Function(double) onTextSizeChanged;

  const HomeScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.textSize,
    required this.onTextSizeChanged,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onDrawerSelect(int index) {
    Navigator.pop(context); // Close the drawer
    if (index == 0) {
      // Already on TranslationScreen, do nothing
      return;
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FavoritesScreen()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HistoryScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingScreen(
            settingsItems: const [],
            toggleTheme: widget.toggleTheme,
            isDarkMode: widget.isDarkMode,
            onTextSizeChanged: widget.onTextSizeChanged,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
              leading: const Icon(Icons.translate),
              title: const Text('Translation'),
              selected: true,
              onTap: () => _onDrawerSelect(0),
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: () => _onDrawerSelect(1),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () => _onDrawerSelect(2),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => _onDrawerSelect(3),
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
      drawerEnableOpenDragGesture: false,
      body: TranslationScreen(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
        openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        textSize: widget.textSize,
      ),
    );
  }
}
