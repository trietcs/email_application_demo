import 'package:email_application/config/app_colors.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';
import 'package:email_application/screens/profile/view_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:email_application/screens/inbox/inbox_screen.dart';
import 'package:email_application/screens/sent/sent_screen.dart';
import 'package:email_application/screens/drafts/drafts_screen.dart';
import 'package:email_application/screens/trash/trash_screen.dart';
import 'package:email_application/screens/starred/starred_screen.dart';
import 'package:email_application/screens/labels/manage_labels_screen.dart';
import 'package:email_application/screens/labels/label_email_list_body.dart';
import 'package:email_application/models/label_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_application/screens/search/email_search_delegate.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentStaticScreenIndex = 0;
  User? _currentUser;

  LabelData? _selectedLabelForView;
  String _currentAppBarTitle = 'Inbox';

  final List<Widget> _staticScreens = [
    const InboxScreen(),
    const SentScreen(),
    const StarredScreen(),
    const DraftsScreen(),
    const TrashScreen(),
    const ViewProfileScreen(),
  ];

  final List<String> _staticTitles = [
    'Inbox',
    'Sent',
    'Starred',
    'Drafts',
    'Trash',
    'Profile',
  ];

  List<LabelData> _userLabelsForDrawer = [];
  bool _isLoadingDrawerLabels = true;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
    } else {
      _currentAppBarTitle = _staticTitles[_currentStaticScreenIndex];
      _fetchUserLabelsForDrawer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context);
    final newUser = authService.currentUser;
    if (newUser != _currentUser) {
      _currentUser = newUser;
      if (_currentUser == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        });
      } else {
        _fetchUserLabelsForDrawer();
        _switchToStaticScreen(0, shouldPopDrawer: false);
      }
    }
  }

  Future<void> _fetchUserLabelsForDrawer() async {
    if (_currentUser == null || !mounted) {
      if (mounted) setState(() => _isLoadingDrawerLabels = false);
      return;
    }
    if (mounted) setState(() => _isLoadingDrawerLabels = true);
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final labels = await firestoreService.getLabelsForUser(_currentUser!.uid);
      if (mounted) {
        setState(() {
          _userLabelsForDrawer = labels;
          _isLoadingDrawerLabels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDrawerLabels = false);
        print("MainScreen: Error fetching labels for drawer: $e");
      }
    }
  }

  void _switchToStaticScreen(int index, {bool shouldPopDrawer = true}) {
    if (index >= 0 && index < _staticTitles.length) {
      setState(() {
        _currentStaticScreenIndex = index;
        _selectedLabelForView = null;
        _currentAppBarTitle = _staticTitles[index];
      });
    }
    if (shouldPopDrawer && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _switchToLabelView(LabelData label) {
    setState(() {
      _selectedLabelForView = label;
      _currentStaticScreenIndex = -1;
      _currentAppBarTitle = label.name;
    });
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildCurrentViewWidget() {
    if (_selectedLabelForView != null) {
      return LabelEmailListBody(
        key: ValueKey(_selectedLabelForView!.id),
        label: _selectedLabelForView!,
      );
    }
    if (_currentStaticScreenIndex >= 0 &&
        _currentStaticScreenIndex < _staticScreens.length) {
      return _staticScreens[_currentStaticScreenIndex];
    }
    return const InboxScreen();
  }

  Widget _buildStandardDrawerItem({
    required IconData icon,
    required String title,
    required int screenIndex,
  }) {
    final bool isSelected =
        _selectedLabelForView == null &&
        _currentStaticScreenIndex == screenIndex;
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
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppColors.primary : Colors.black87,
          ),
        ),
        selected: isSelected,
        onTap: () => _switchToStaticScreen(screenIndex),
      ),
    );
  }

  Widget _buildRouteDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.secondaryIcon, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLabelDrawerItem(LabelData label) {
    final bool isSelected = _selectedLabelForView?.id == label.id;
    return Material(
      color:
          isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        leading: Icon(
          Icons.label,
          color: isSelected ? AppColors.primary : label.color,
          size: 24,
        ),
        title: Text(
          label.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        selected: isSelected,
        onTap: () => _switchToLabelView(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_currentUser == null && !mounted) {
      return const Scaffold(body: Center(child: Text("User not loaded.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentAppBarTitle,
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
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppColors.primary, size: 28),
            tooltip: 'Search Emails',
            onPressed: () {
              showSearch(
                context: context,
                delegate: EmailSearchDelegate(userId: _currentUser!.uid),
              );
            },
          ),
        ],
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
                          const Icon(
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
                          _currentUser?.displayName ??
                              _currentUser?.email ??
                              'User',
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
                    _buildStandardDrawerItem(
                      icon: Icons.inbox_outlined,
                      title: 'Inbox',
                      screenIndex: 0,
                    ),
                    _buildStandardDrawerItem(
                      icon: Icons.send_outlined,
                      title: 'Sent',
                      screenIndex: 1,
                    ),
                    _buildStandardDrawerItem(
                      icon: Icons.star_outline_rounded,
                      title: 'Starred',
                      screenIndex: 2,
                    ),
                    _buildStandardDrawerItem(
                      icon: Icons.drafts_outlined,
                      title: 'Drafts',
                      screenIndex: 3,
                    ),
                    _buildStandardDrawerItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'Trash',
                      screenIndex: 4,
                    ),
                    const Divider(height: 1),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Text(
                        "LABELS",
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_isLoadingDrawerLabels)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_userLabelsForDrawer.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: Text(
                          "No labels yet. Manage labels to add some.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    else
                      ..._userLabelsForDrawer
                          .map((label) => _buildLabelDrawerItem(label))
                          .toList(),

                    const Divider(height: 1),
                    _buildRouteDrawerItem(
                      icon: Icons.label_outline_rounded,
                      title: 'Manage Labels',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageLabelsScreen(),
                          ),
                        ).then((_) {
                          _fetchUserLabelsForDrawer();
                        });
                      },
                    ),
                    const Divider(height: 1),
                    _buildStandardDrawerItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      screenIndex: 5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildCurrentViewWidget(),
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
}
