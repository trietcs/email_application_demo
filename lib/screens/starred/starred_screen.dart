import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/models/label_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/widgets/email_list_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_application/config/app_colors.dart';
import 'package:email_application/services/view_mode_notifier.dart';
import 'package:email_application/widgets/simple_email_list_item.dart';

class StarredScreen extends StatefulWidget {
  const StarredScreen({super.key});

  @override
  State<StarredScreen> createState() => _StarredScreenState();
}

class _StarredScreenState extends State<StarredScreen> {
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
      if (mounted) setState(() => _isLoadingLabels = false);
      return;
    }

    try {
      await _fetchUserLabels();
      await _setupEmailStream();
      if (mounted) setState(() => _isLoadingLabels = false);
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
      if (mounted) _userLabels = labels;
    } catch (e) {
      if (mounted) print("StarredScreen: Error fetching labels: $e");
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
        _emailsStream = firestoreService.getStarredEmailsStream(
          _currentUser!.uid,
        );
      });
    }
  }

  Future<void> _handleEmailTap(EmailData email) async {
    if (!mounted || _currentUser == null) return;
    dynamic resultFromNextScreen;

    if (email.folder == EmailFolder.drafts) {
      resultFromNextScreen = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ComposeEmailScreen(draftToEdit: email),
        ),
      );
    } else {
      resultFromNextScreen = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewEmailScreen(emailData: email),
        ),
      );
    }

    if (resultFromNextScreen == true ||
        resultFromNextScreen == false ||
        (resultFromNextScreen == null && mounted)) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view starred emails.')),
      );
    }

    final viewMode = Provider.of<ViewModeNotifier>(context).viewMode;
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
                  return EmailListErrorView(
                    error: snapshot.error!,
                    onRetry: _setupEmailStream,
                  );
                }

                final starredEmails = snapshot.data ?? [];
                if (starredEmails.isEmpty) {
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.star_outline_rounded,
                                size: 60,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No starred emails yet!',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  itemCount: starredEmails.length,
                  itemBuilder: (context, index) {
                    final email = starredEmails[index];

                    if (viewMode == ViewMode.basic) {
                      return SimpleEmailListItem(
                        email: email,
                        currentScreenFolder: email.folder,
                        onTap: () => _handleEmailTap(email),
                        onStarStatusChanged: null,
                      );
                    } else {
                      return EmailListItem(
                        email: email,
                        currentScreenFolder: email.folder,
                        allUserLabels: _userLabels,
                        onTap: () => _handleEmailTap(email),
                        onReadStatusChanged: null,
                        onDeleteOrMove: null,
                        onStarStatusChanged: null,
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
