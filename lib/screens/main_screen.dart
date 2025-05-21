import 'package:email_application/screens/emails/compose_email_screen.dart';
import 'package:email_application/screens/profile/view_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:email_application/screens/inbox/inbox_screen.dart';
import 'package:email_application/screens/sent/sent_screen.dart';
import 'package:email_application/screens/drafts/drafts_screen.dart';
import 'package:email_application/screens/trash/trash_screen.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const InboxScreen(),
    const SentScreen(),
    const DraftsScreen(),
    const TrashScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Người dùng không hợp lệ. Vui lòng đăng nhập lại.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ViewProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'Hộp thư đến',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Đã gửi'),
          BottomNavigationBarItem(icon: Icon(Icons.drafts), label: 'Bản nháp'),
          BottomNavigationBarItem(icon: Icon(Icons.delete), label: 'Thùng rác'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeEmailScreen()),
          );
        },
        tooltip: 'Soạn thư mới',
        child: const Icon(Icons.edit),
      ),
    );
  }
}
