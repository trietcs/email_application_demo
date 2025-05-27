import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/widgets/email_list_view.dart'; // For EmailListErrorView
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_application/config/app_colors.dart';

class StarredScreen extends StatefulWidget {
  const StarredScreen({super.key});

  @override
  State<StarredScreen> createState() => _StarredScreenState();
}

class _StarredScreenState extends State<StarredScreen> {
  User? _currentUser;
  bool _isLoading = true;
  List<EmailData> _starredEmails = []; // Now directly a list of EmailData
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _loadStarredEmails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context);
    final newUser = authService.currentUser;

    if (newUser != _currentUser) {
      _currentUser = newUser;
      _loadStarredEmails();
    }
  }

  Future<void> _loadStarredEmails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _starredEmails = [];
    });

    if (_currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final List<Map<String, dynamic>> flatRawEmailList = await firestoreService
          .getStarredEmails(_currentUser!.uid);

      if (!mounted) return;

      List<EmailData> loadedEmails =
          flatRawEmailList.map((rawEmail) {
            return EmailData.fromMap(rawEmail, rawEmail['id'] as String? ?? '');
          }).toList();

      // Sort emails by time, most recent first (already done by Firestore query, but can be re-asserted here if needed)
      // loadedEmails.sort((a, b) => DateTime.parse(b.time).compareTo(DateTime.parse(a.time)));

      if (mounted) {
        setState(() {
          _starredEmails = loadedEmails;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        print('StarredScreen _loadStarredEmails Error: $e');
      }
    }
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
      _loadStarredEmails();
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
          if (!doc.exists || !(doc.data()?['isStarred'] ?? false)) {
            _loadStarredEmails();
          }
        }
      } catch (e) {
        print("Error checking email status after pop from ViewEmailScreen: $e");
        if (mounted) {
          _loadStarredEmails();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view starred emails.')),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStarredEmails,
        color: AppColors.primary,
        child: Builder(
          builder: (context) {
            if (_isLoading) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (_error != null) {
              return EmailListErrorView(
                error: _error!,
                onRetry: _loadStarredEmails,
              );
            }

            if (_starredEmails.isEmpty) {
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
              itemCount: _starredEmails.length,
              itemBuilder: (context, index) {
                final email = _starredEmails[index];
                return EmailListItem(
                  email: email,
                  currentScreenFolder:
                      email.folder, // Use the email's actual folder for context
                  onTap: () => _handleEmailTap(email),
                  onReadStatusChanged: _loadStarredEmails,
                  onDeleteOrMove: _loadStarredEmails,
                  onStarStatusChanged: _loadStarredEmails,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
