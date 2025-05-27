import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/models/label_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';
import 'package:email_application/widgets/email_list_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_application/config/app_colors.dart';

class SentScreen extends StatefulWidget {
  const SentScreen({super.key});

  @override
  State<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends State<SentScreen> {
  User? _currentUser;
  Future<List<EmailData>>? _emailsFuture;
  List<LabelData> _userLabels = [];
  bool _isLoadingInitialData = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _loadInitialScreenData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context);
    final newUser = authService.currentUser;
    if (newUser != _currentUser) {
      _currentUser = newUser;
      _loadInitialScreenData();
    }
  }

  Future<void> _loadInitialScreenData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInitialData = true;
      _error = null;
    });

    if (_currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoadingInitialData = false;
          _emailsFuture = Future.value([]);
        });
      }
      return;
    }

    try {
      await _fetchUserLabels();
      _loadEmails();
      if (mounted) {
        setState(() {
          _isLoadingInitialData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingInitialData = false;
          _emailsFuture = Future.value([]);
        });
      }
    }
  }

  Future<void> _fetchUserLabels() async {
    if (_currentUser == null || !mounted) {
      if (mounted) _userLabels = [];
      return;
    }
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final labels = await firestoreService.getLabelsForUser(_currentUser!.uid);
      if (mounted) {
        _userLabels = labels;
      }
    } catch (e) {
      if (mounted) {
        print("SentScreen: Error fetching labels: $e");
      }
      throw e;
    }
  }

  Future<void> _loadEmails() async {
    if (_currentUser != null && mounted) {
      setState(() {
        _emailsFuture = _fetchEmailsFromService(
          _currentUser!.uid,
          EmailFolder.sent,
        );
      });
    } else if (mounted) {
      setState(() {
        _emailsFuture = Future.value([]);
      });
    }
  }

  Future<List<EmailData>> _fetchEmailsFromService(
    String userId,
    EmailFolder folder,
  ) async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final List<Map<String, dynamic>> emailsDataMap = await firestoreService
        .getEmails(userId, folder);

    if (!mounted) return [];

    return emailsDataMap.map((emailMap) {
      EmailData email = EmailData.fromMap(
        emailMap,
        emailMap['id'] as String? ?? '',
      );
      if (!email.isRead) {
        return email.copyWith(isRead: true);
      }
      return email;
    }).toList();
  }

  Future<void> _handleEmailTap(EmailData email) async {
    if (!mounted || _currentUser == null) return;
    final resultFromView = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewEmailScreen(emailData: email),
      ),
    );
    if (resultFromView == true) {
      _loadInitialScreenData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your sent emails.')),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadInitialScreenData,
        color: AppColors.primary,
        child: Builder(
          builder: (context) {
            if (_isLoadingInitialData && _emailsFuture == null) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (_error != null && _emailsFuture == null) {
              return EmailListErrorView(
                error: _error!,
                onRetry: _loadInitialScreenData,
              );
            }

            return FutureBuilder<List<EmailData>>(
              future: _emailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (snapshot.hasError) {
                  print(
                    'SentScreen Email FutureBuilder Error: ${snapshot.error}',
                  );
                  return EmailListErrorView(
                    error: snapshot.error!,
                    onRetry: _loadEmails,
                  );
                }
                if (_error != null &&
                    (snapshot.data == null || snapshot.data!.isEmpty)) {
                  return EmailListErrorView(
                    error: _error!,
                    onRetry: _loadInitialScreenData,
                  );
                }

                final emails = snapshot.data ?? [];
                return EmailListView(
                  emails: emails,
                  currentScreenFolder: EmailFolder.sent,
                  allUserLabels: _userLabels,
                  onEmailTap: _handleEmailTap,
                  onRefresh: _loadInitialScreenData,
                  onReadStatusChanged: _loadInitialScreenData,
                  onDeleteOrMove: _loadInitialScreenData,
                  onStarStatusChanged: _loadInitialScreenData,
                  emptyListMessage: "You haven't sent any emails yet.",
                  emptyListIcon: Icons.outbox_outlined,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
