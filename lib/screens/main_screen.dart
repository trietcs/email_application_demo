import 'package:email_application/config/app_colors.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';
import 'package:email_application/screens/profile/view_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:email_application/screens/inbox/inbox_screen.dart';
import 'package:email_application/screens/sent/sent_screen.dart';
import 'package:email_application/screens/drafts/drafts_screen.dart';
import 'package:email_application/screens/trash/trash_screen.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    const ViewProfileScreen(),
  ];

  final List<String> _titles = ['Inbox', 'Sent', 'Drafts', 'Trash', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final User? user =
        Provider.of<AuthService>(context, listen: false).currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Please log in again.',
            style: TextStyle(fontSize: 16, color: AppColors.secondaryText),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.appBarForeground,
          ),
        ),
        backgroundColor: AppColors.appBarBackground,
        elevation: 1,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: Icon(Icons.menu, color: AppColors.primary, size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: AppColors.primary),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email_rounded,
                            size: 36,
                            color: AppColors.onPrimary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'TVA MAIL',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(
                          user.displayName ?? user.email ?? 'User',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.onPrimary.withOpacity(0.85),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(
                      icon: Icons.inbox_outlined,
                      title: 'Inbox',
                      index: 0,
                    ),
                    _buildDrawerItem(
                      icon: Icons.send_outlined,
                      title: 'Sent',
                      index: 1,
                    ),
                    _buildDrawerItem(
                      icon: Icons.drafts_outlined,
                      title: 'Drafts',
                      index: 2,
                    ),
                    _buildDrawerItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'Trash',
                      index: 3,
                    ),
                    Divider(color: Colors.grey.shade300, height: 1),
                    _buildDrawerItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      index: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeEmailScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        tooltip: 'Compose',
        child: Icon(Icons.edit_outlined, color: AppColors.onPrimary, size: 26),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final bool isSelected = _currentIndex == index;
    return Material(
      color:
          isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.secondaryIcon,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.primary : Colors.black87,
          ),
        ),
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}
