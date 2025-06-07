import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/models/label_data.dart';
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
  User? _currentUser;
  Stream<List<EmailData>>? _emailsStream;
  List<LabelData> _userLabels = [];
  bool _isLoadingLabels = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context);
    final newUser = authService.currentUser;
    if (newUser != _currentUser) {
      _currentUser = newUser;
      _initializeData();
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLabels = true;
      _error = null;
      _emailsStream = null;
    });

    if (_currentUser == null) {
      if (mounted) {
        setState(() => _isLoadingLabels = false);
      }
      return;
    }

    try {
      await _fetchUserLabels();
      await _setupEmailStream();
      if (mounted) {
        setState(() {
          _isLoadingLabels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingLabels = false;
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
        print("DraftsScreen: Error fetching labels: $e");
      }
      throw e;
    }
  }

  Future<void> _setupEmailStream() async {
    if (_currentUser != null && mounted) {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      setState(() {
        _emailsStream = firestoreService.getEmailsStream(
          _currentUser!.uid,
          EmailFolder.drafts,
        );
      });
    }
  }

  Future<void> _handleDraftTap(EmailData draftEmail) async {
    if (!mounted || _currentUser == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComposeEmailScreen(draftToEdit: draftEmail),
      ),
    );
    if (result == true || result == false || result == null && mounted) {
      _initializeData();
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
        onRefresh: _initializeData,
        color: AppColors.primary,
        child: Builder(
          builder: (context) {
            if (_isLoadingLabels) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (_error != null) {
              return EmailListErrorView(
                error: _error!,
                onRetry: _initializeData,
              );
            }

            return StreamBuilder<List<EmailData>>(
              stream: _emailsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (snapshot.hasError) {
                  print(
                    'DraftsScreen Email StreamBuilder Error: ${snapshot.error}',
                  );
                  return EmailListErrorView(
                    error: snapshot.error!,
                    onRetry: _setupEmailStream,
                  );
                }

                final emails = snapshot.data ?? [];

                final processedEmails =
                    emails.map((email) {
                      return email.copyWith(isRead: true);
                    }).toList();

                return EmailListView(
                  emails: processedEmails,
                  currentScreenFolder: EmailFolder.drafts,
                  allUserLabels: _userLabels,
                  onEmailTap: _handleDraftTap,
                  onRefresh: _initializeData,
                  onReadStatusChanged: null,
                  onDeleteOrMove: null,
                  onStarStatusChanged: null,
                  emptyListMessage: "You have no saved drafts.",
                  emptyListIcon: Icons.edit_note_outlined,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
