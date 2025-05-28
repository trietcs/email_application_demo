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

class LabelEmailListBody extends StatefulWidget {
  final LabelData label;

  const LabelEmailListBody({super.key, required this.label});

  @override
  State<LabelEmailListBody> createState() => _LabelEmailListBodyState();
}

class _LabelEmailListBodyState extends State<LabelEmailListBody> {
  User? _currentUser;
  Future<List<EmailData>>? _emailsFuture;
  List<LabelData> _allUserLabels = [];
  bool _isLoadingInitialData = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _loadInitialScreenData();
  }

  @override
  void didUpdateWidget(LabelEmailListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.label.id != oldWidget.label.id) {
      _loadInitialScreenData();
    }
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
      _loadEmailsForLabel();
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
      if (mounted) _allUserLabels = [];
      return;
    }
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final labels = await firestoreService.getLabelsForUser(_currentUser!.uid);
      if (mounted) {
        _allUserLabels = labels;
      }
    } catch (e) {
      if (mounted) {
        print("LabelEmailListBody: Error fetching all user labels: $e");
      }
      throw e;
    }
  }

  Future<void> _loadEmailsForLabel() async {
    if (_currentUser != null && mounted) {
      setState(() {
        _emailsFuture = _fetchEmailsByLabelFromService(
          _currentUser!.uid,
          widget.label.id,
        );
      });
    } else if (mounted) {
      setState(() {
        _emailsFuture = Future.value([]);
      });
    }
  }

  Future<List<EmailData>> _fetchEmailsByLabelFromService(
    String userId,
    String labelId,
  ) async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final List<Map<String, dynamic>> emailsDataMap = await firestoreService
        .getEmailsByLabel(userId, labelId);

    if (!mounted) return [];

    return emailsDataMap
        .map((map) => EmailData.fromMap(map, map['id'] as String? ?? ''))
        .toList();
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
        (resultFromNextScreen == null && mounted)) {
      _loadInitialScreenData();
    } else {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      try {
        final doc =
            await firestoreService.usersCollection
                .doc(_currentUser!.uid)
                .collection('userEmails')
                .doc(email.id)
                .get();
        if (mounted) {
          if (!doc.exists) {
            _loadInitialScreenData();
          } else {
            final updatedEmailData = EmailData.fromMap(doc.data()!, doc.id);
            if (!updatedEmailData.labelIds.contains(widget.label.id)) {
              _loadInitialScreenData();
            }
          }
        }
      } catch (e) {
        print("Error checking email status after pop from next screen: $e");
        if (mounted) _loadInitialScreenData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
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
              if (snapshot.connectionState == ConnectionState.waiting ||
                  (_isLoadingInitialData && _emailsFuture != null)) {
                return Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (snapshot.hasError) {
                print(
                  'LabelEmailListBody Email FutureBuilder Error: ${snapshot.error}',
                );
                return EmailListErrorView(
                  error: snapshot.error!,
                  onRetry: _loadEmailsForLabel,
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
                            Text(
                              "No emails found with the label \"${widget.label.name}\".",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
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

                  return EmailListItem(
                    email: email,
                    currentScreenFolder: itemDisplayContextFolder,
                    allUserLabels: _allUserLabels,
                    onTap: () => _handleEmailTap(email),
                    onReadStatusChanged: _loadInitialScreenData,
                    onDeleteOrMove: _loadInitialScreenData,
                    onStarStatusChanged: _loadInitialScreenData,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
