import 'package:flutter/material.dart';
import 'fields_page.dart';
import 'options_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    FieldsPage(),
    OptionsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.redAccent,
          selectedItemColor: Colors.white,
          unselectedItemColor: const Color.fromARGB(125, 255, 255, 255),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.stadium),
              label: 'الملاعب',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu),
              label: 'الخيارات',
            ),
          ],
        ),
      ),
    );
  }
}
