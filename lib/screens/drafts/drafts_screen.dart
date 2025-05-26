import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';
import 'package:email_application/widgets/email_list_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_application/config/app_colors.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  late Future<List<EmailData>> _emailsFuture;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _loadEmails();
  }

  Future<void> _loadEmails() async {
    if (_currentUser != null) {
      if (mounted) {
        setState(() {
          _emailsFuture = _fetchEmails(
            context,
            _currentUser!.uid,
            EmailFolder.drafts,
          );
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _emailsFuture = Future.value([]);
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = Provider.of<User?>(context);
    if (newUser != _currentUser) {
      _currentUser = newUser;
      _loadEmails();
    }
  }

  Future<List<EmailData>> _fetchEmails(
    BuildContext context,
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
      return email.copyWith(senderEmail: userId, isRead: true);
    }).toList();
  }

  Future<void> _handleDraftTap(EmailData draftEmail) async {
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComposeEmailScreen(draftToEdit: draftEmail),
      ),
    );
    if (result == true || result == false && mounted) {
      _loadEmails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your drafts.')),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadEmails(),
        color: AppColors.primary,
        child: FutureBuilder<List<EmailData>>(
          future: _emailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError) {
              print('DraftsScreen FutureBuilder Error: ${snapshot.error}');
              return EmailListErrorView(
                error: snapshot.error!,
                onRetry: _loadEmails,
              );
            }

            final emails = snapshot.data ?? [];
            return EmailListView(
              emails: emails,
              currentScreenFolder: EmailFolder.drafts,
              onEmailTap: _handleDraftTap,
              onRefresh: _loadEmails,
              onReadStatusChanged: null,
              onDeleteOrMove: _loadEmails,
            );
          },
        ),
      ),
    );
  }
}
