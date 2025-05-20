import 'package:email_application/screens/drafts/drafts_screen.dart';
import 'package:email_application/screens/inbox/inbox_screen.dart';
import 'package:email_application/screens/sent/sent_screen.dart';
import 'package:email_application/screens/trash/trash_screen.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Danh sách các màn hình tương ứng với các tab
  static const List<Widget> _screens = [
    InboxScreen(),
    SentScreen(),
    DraftsScreen(),
    TrashScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TVA Email')),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'Hộp thư đến',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Đã gửi'),
          BottomNavigationBarItem(icon: Icon(Icons.drafts), label: 'Bản nháp'),
          BottomNavigationBarItem(icon: Icon(Icons.delete), label: 'Thùng rác'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
