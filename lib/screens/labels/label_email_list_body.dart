import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/label_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';
import 'package:email_application/widgets/email_list_view.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_application/config/app_colors.dart';
import 'package:email_application/services/view_mode_notifier.dart';
import 'package:email_application/widgets/simple_email_list_item.dart';

class LabelEmailListBody extends StatefulWidget {
  final LabelData label;

  const LabelEmailListBody({super.key, required this.label});

  @override
  State<LabelEmailListBody> createState() => _LabelEmailListBodyState();
}

class _LabelEmailListBodyState extends State<LabelEmailListBody> {
  User? _currentUser;
  Stream<List<EmailData>>? _emailsStream;
  List<LabelData> _allUserLabels = [];
  bool _isLoadingLabels = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _initializeData();
  }

  @override
  void didUpdateWidget(LabelEmailListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.label.id != oldWidget.label.id) {
      _initializeData();
    }
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
      if (mounted) _allUserLabels = [];
      return;
    }
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final labels = await firestoreService.getLabelsForUser(_currentUser!.uid);
      if (mounted) _allUserLabels = labels;
    } catch (e) {
      if (mounted)
        print("LabelEmailListBody: Error fetching all user labels: $e");
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
        _emailsStream = firestoreService.getEmailsByLabelStream(
          _currentUser!.uid,
          widget.label.id,
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
    final viewMode = Provider.of<ViewModeNotifier>(context).viewMode;

    return RefreshIndicator(
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
            return EmailListErrorView(error: _error!, onRetry: _initializeData);
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
                  'LabelEmailListBody Email StreamBuilder Error: ${snapshot.error}',
                );
                return EmailListErrorView(
                  error: snapshot.error!,
                  onRetry: _setupEmailStream,
                );
              }

              final emails = snapshot.data ?? [];

              if (emails.isEmpty) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.label_off_outlined,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Text(
                                "No emails found with the label \"${widget.label.name}\".",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
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
                itemCount: emails.length,
                itemBuilder: (context, index) {
                  final email = emails[index];
                  EmailFolder itemDisplayContextFolder = email.folder;
                  if (email.folder == EmailFolder.trash &&
                      email.originalFolder != null) {
                    itemDisplayContextFolder = email.originalFolder!;
                  }

                  if (viewMode == ViewMode.basic) {
                    return SimpleEmailListItem(
                      email: email,
                      currentScreenFolder: itemDisplayContextFolder,
                      onTap: () => _handleEmailTap(email),
                      onStarStatusChanged: null,
                    );
                  } else {
                    return EmailListItem(
                      email: email,
                      currentScreenFolder: itemDisplayContextFolder,
                      allUserLabels: _allUserLabels,
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
    );
  }
}
