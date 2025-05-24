import 'dart:io';
import 'package:email_application/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/models/email_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComposeEmailScreen extends StatefulWidget {
  final EmailData? replyToEmail;
  final EmailData? forwardEmail;
  final EmailData? draftToEdit;

  const ComposeEmailScreen({
    super.key,
    this.replyToEmail,
    this.forwardEmail,
    this.draftToEdit,
  });

  @override
  State<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _bccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _isProcessing = false;
  bool _showCcBccFields = false;

  String _editingDraftId = '';
  List<PlatformFile> _attachments = [];
  List<Map<String, String>> _initialAttachmentsFromDraft = [];

  final double _textFieldVerticalPadding = 15.0;

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  String _formatRecipientForDisplay(Map<String, String> recipientMap) {
    return recipientMap['displayName'] ?? recipientMap['userId'] ?? '';
  }

  void _populateFields() {
    if (widget.replyToEmail != null) {
      final originalEmail = widget.replyToEmail!;
      _toController.text = _formatRecipientForDisplay({
        'userId': originalEmail.senderEmail,
        'displayName': originalEmail.senderName,
      });
      _subjectController.text =
          originalEmail.subject.toLowerCase().startsWith('re:')
              ? originalEmail.subject
              : 'Re: ${originalEmail.subject}';
      _bodyController.text =
          '\n\n\n--- Original message on ${_formatDateTimeForQuote(originalEmail.time)} ---\nFrom: ${originalEmail.senderName} <${originalEmail.senderEmail}>\nSubject: ${originalEmail.subject}\n\n${originalEmail.body}';
      _bodyController.selection = TextSelection.fromPosition(
        const TextPosition(offset: 0),
      );
      if (originalEmail.cc != null && originalEmail.cc!.isNotEmpty) {
        _ccController.text = originalEmail.cc!
            .map((r) => _formatRecipientForDisplay(r))
            .where((s) => s.isNotEmpty)
            .join(', ');
        _showCcBccFields = true;
      }
    } else if (widget.forwardEmail != null) {
      final originalEmail = widget.forwardEmail!;
      _subjectController.text =
          originalEmail.subject.toLowerCase().startsWith('fw:')
              ? originalEmail.subject
              : 'Fw: ${originalEmail.subject}';
      _bodyController.text =
          '\n\n\n--- Forwarded message ---\nFrom: ${originalEmail.senderName} <${originalEmail.senderEmail}>\nDate: ${_formatDateTimeForQuote(originalEmail.time)}\nSubject: ${originalEmail.subject}\nTo: ${originalEmail.to.map((r) => _formatRecipientForDisplay(r)).join(', ')}\n${originalEmail.cc != null && originalEmail.cc!.isNotEmpty ? 'Cc: ${originalEmail.cc!.map((r) => _formatRecipientForDisplay(r)).join(', ')}\n' : ''}\n${originalEmail.body}';
      if (originalEmail.attachments != null &&
          originalEmail.attachments!.isNotEmpty) {
        _initialAttachmentsFromDraft = List<Map<String, String>>.from(
          originalEmail.attachments!,
        );
      }
    } else if (widget.draftToEdit != null) {
      final draft = widget.draftToEdit!;
      _toController.text = draft.to
          .map((r) => _formatRecipientForDisplay(r))
          .where((s) => s.isNotEmpty)
          .join(', ');
      _ccController.text =
          draft.cc
              ?.map((r) => _formatRecipientForDisplay(r))
              .where((s) => s.isNotEmpty)
              .join(', ') ??
          '';
      _bccController.text =
          draft.bcc
              ?.map((r) => _formatRecipientForDisplay(r))
              .where((s) => s.isNotEmpty)
              .join(', ') ??
          '';
      if (_ccController.text.isNotEmpty || _bccController.text.isNotEmpty) {
        _showCcBccFields = true;
      }
      _subjectController.text = draft.subject;
      _bodyController.text = draft.body;
      _editingDraftId = draft.id;
      _initialAttachmentsFromDraft = List<Map<String, String>>.from(
        draft.attachments ?? [],
      );
    }
  }

  String _formatDateTimeForQuote(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm', 'vi_VN').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  Future<List<Map<String, String>>> _uploadAttachments(
    String userId,
    String emailIdForStorage,
  ) async {
    List<Map<String, String>> attachmentUrls = [];
    if (_attachments.isEmpty) return attachmentUrls;

    for (PlatformFile file in _attachments) {
      if (file.path == null) continue;
      final File localFile = File(file.path!);
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('email_attachments')
          .child(userId)
          .child(emailIdForStorage)
          .child(fileName);
      try {
        final UploadTask uploadTask = storageRef.putFile(localFile);
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        attachmentUrls.add({
          'name': file.name,
          'url': downloadUrl,
          'size': file.size.toString(),
        });
      } catch (e) {
        print("Error uploading attachment ${file.name}: $e");
      }
    }
    return attachmentUrls;
  }

  Future<List<Map<String, String>>> _getRecipientsDataByEmail(
    String controllerText,
    FirestoreService fs,
  ) async {
    if (controllerText.isEmpty) return [];
    final List<String> contacts =
        controllerText
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    List<Map<String, String>> recipientsData = [];
    bool allFound = true;

    for (String contact in contacts) {
      final userInfo = await fs.findUserByContactInfo(contact);
      if (userInfo != null &&
          userInfo['userId'] != null &&
          userInfo['displayName'] != null) {
        recipientsData.add({
          'userId': userInfo['userId']!,
          'displayName': userInfo['displayName']!,
        });
      } else {
        allFound = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recipient not found: $contact')),
          );
        }
        break;
      }
    }
    if (!allFound) return [];
    return recipientsData;
  }

  Future<void> _sendEmail(User currentUser) async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isProcessing = true);

    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final String senderId = currentUser.uid;
    final String senderDisplayName =
        currentUser.displayName?.isNotEmpty == true
            ? currentUser.displayName!
            : (currentUser.email?.split('@')[0] ?? 'Sender');

    List<Map<String, String>> toRecipients = await _getRecipientsDataByEmail(
      _toController.text,
      firestoreService,
    );
    List<Map<String, String>> ccRecipients = await _getRecipientsDataByEmail(
      _ccController.text,
      firestoreService,
    );
    List<Map<String, String>> bccRecipients = await _getRecipientsDataByEmail(
      _bccController.text,
      firestoreService,
    );

    if (toRecipients.isEmpty && ccRecipients.isEmpty && bccRecipients.isEmpty) {
      if (_toController.text.isNotEmpty ||
          _ccController.text.isNotEmpty ||
          _bccController.text.isNotEmpty) {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter at least one valid recipient (To, CC, or BCC).',
            ),
          ),
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    final String tempEmailIdForStorage =
        FirebaseFirestore.instance.collection('temp').doc().id;
    List<Map<String, String>> uploadedAttachments = await _uploadAttachments(
      senderId,
      tempEmailIdForStorage,
    );
    List<Map<String, String>> allAttachmentsToSend = [
      ..._initialAttachmentsFromDraft,
      ...uploadedAttachments,
    ];

    try {
      await firestoreService.sendEmail(
        senderId: senderId,
        senderDisplayName: senderDisplayName,
        to: toRecipients,
        cc: ccRecipients,
        bcc: bccRecipients,
        subject: _subjectController.text,
        body: _bodyController.text,
        attachments: allAttachmentsToSend,
      );

      if (_editingDraftId.isNotEmpty) {
        await firestoreService.deleteEmailPermanently(
          userId: senderId,
          emailId: _editingDraftId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Email sent!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send email: ${e.toString()}')),
        );
      }
      print("Error sending email: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSaveDraftAndExit(User currentUser) async {
    if (!mounted) return;

    bool hasContentToSave =
        _toController.text.isNotEmpty ||
        _ccController.text.isNotEmpty ||
        _bccController.text.isNotEmpty ||
        _subjectController.text.isNotEmpty ||
        _bodyController.text.isNotEmpty ||
        _attachments.isNotEmpty ||
        _initialAttachmentsFromDraft.isNotEmpty;

    bool hasActualChangesFromDraft = true;
    if (widget.draftToEdit != null) {
      hasActualChangesFromDraft =
          !(_toController.text ==
                  (widget.draftToEdit!.to
                      .map(_formatRecipientForDisplay)
                      .join(', ')) &&
              _ccController.text ==
                  (widget.draftToEdit!.cc
                          ?.map(_formatRecipientForDisplay)
                          .join(', ') ??
                      '') &&
              _bccController.text ==
                  (widget.draftToEdit!.bcc
                          ?.map(_formatRecipientForDisplay)
                          .join(', ') ??
                      '') &&
              _subjectController.text == widget.draftToEdit!.subject &&
              _bodyController.text == widget.draftToEdit!.body &&
              _attachments.isEmpty &&
              _initialAttachmentsFromDraft.length ==
                  (widget.draftToEdit!.attachments?.length ?? 0));
    }

    if (!hasContentToSave && _editingDraftId.isEmpty) {
      print(
        "ComposeEmailScreen: Nothing to save (new email is empty). Closing.",
      );
      if (mounted) Navigator.pop(context, false);
      return;
    }

    if (!hasActualChangesFromDraft && _editingDraftId.isNotEmpty) {
      print("ComposeEmailScreen: No actual changes from draft. Closing.");
      if (mounted) Navigator.pop(context, false);
      return;
    }

    if (mounted) setState(() => _isProcessing = true);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final String senderId = currentUser.uid;
    final String senderDisplayName =
        currentUser.displayName?.isNotEmpty == true
            ? currentUser.displayName!
            : (currentUser.email?.split('@')[0] ?? 'Sender');

    List<Map<String, String>> formatRecipientsForDraft(String controllerText) {
      return controllerText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((contact) => {'userId': '', 'displayName': contact})
          .toList();
    }

    List<Map<String, String>> toRecipientsDraft = formatRecipientsForDraft(
      _toController.text,
    );
    List<Map<String, String>> ccRecipientsDraft = formatRecipientsForDraft(
      _ccController.text,
    );
    List<Map<String, String>> bccRecipientsDraft = formatRecipientsForDraft(
      _bccController.text,
    );

    final String draftIdForStorage =
        _editingDraftId.isNotEmpty
            ? _editingDraftId
            : FirebaseFirestore.instance.collection('temp').doc().id;
    List<Map<String, String>> newUploadedAttachments = await _uploadAttachments(
      senderId,
      draftIdForStorage,
    );
    List<Map<String, String>> allAttachmentsForDraft = [
      ..._initialAttachmentsFromDraft,
      ...newUploadedAttachments,
    ];

    try {
      if (_editingDraftId.isNotEmpty) {
        await firestoreService.updateDraft(
          userId: senderId,
          draftId: _editingDraftId,
          senderDisplayName: senderDisplayName,
          to: toRecipientsDraft,
          cc: ccRecipientsDraft,
          bcc: bccRecipientsDraft,
          subject: _subjectController.text,
          body: _bodyController.text,
          attachments: allAttachmentsForDraft,
        );
      } else {
        if (hasContentToSave) {
          _editingDraftId = await firestoreService.saveDraft(
            userId: senderId,
            senderDisplayName: senderDisplayName,
            to: toRecipientsDraft,
            cc: ccRecipientsDraft,
            bcc: bccRecipientsDraft,
            subject: _subjectController.text,
            body: _bodyController.text,
            attachments: allAttachmentsForDraft,
          );
        }
      }
      if (mounted && hasContentToSave && hasActualChangesFromDraft) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to drafts')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save draft: ${e.toString()}')),
        );
      }
      print("Error saving draft: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      print("Error picking files: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error picking files: $e")));
      }
    }
  }

  void _removeAttachment(int index, {bool isInitial = false}) {
    setState(() {
      if (isInitial) {
        _initialAttachmentsFromDraft.removeAt(index);
      } else {
        _attachments.removeAt(index);
      }
    });
  }

  Widget _buildRecipientField({
    required TextEditingController controller,
    required String label,
    FocusNode? focusNode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(
            right: 8.0,
            top: _textFieldVerticalPadding,
            bottom: _textFieldVerticalPadding,
          ),
          child: Text(
            label,
            style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: _textFieldVerticalPadding,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compose Email')),
        body: const Center(child: Text('Please log in to compose an email.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarBackground,
        iconTheme: IconThemeData(color: AppColors.primary),
        title: Text(
          'Compose Email',
          style: TextStyle(
            color: AppColors.appBarForeground,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Save Draft & Close',
          onPressed: () => _handleSaveDraftAndExit(currentUser),
        ),
        actions: [
          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onPrimary,
                ),
              ),
            )
          else ...[
            IconButton(
              icon: Icon(Icons.attach_file, color: AppColors.primary),
              tooltip: 'Attach files',
              onPressed: _pickFiles,
            ),
            IconButton(
              icon: Icon(Icons.drafts_outlined, color: AppColors.primary),
              tooltip: 'Save draft & Close',
              onPressed: () => _handleSaveDraftAndExit(currentUser),
            ),
            IconButton(
              icon: Icon(Icons.send_outlined, color: AppColors.primary),
              tooltip: 'Send',
              onPressed: () => _sendEmail(currentUser),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildRecipientField(
                      controller: _toController,
                      label: "To:",
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showCcBccFields ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.secondaryIcon,
                    ),
                    onPressed: () {
                      setState(() {
                        _showCcBccFields = !_showCcBccFields;
                      });
                    },
                  ),
                ],
              ),
              if (_showCcBccFields) ...[
                _buildRecipientField(controller: _ccController, label: "Cc:"),
                _buildRecipientField(controller: _bccController, label: "Bcc:"),
              ],
              const Divider(height: 1, thickness: 0.5),

              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Subject',
                  contentPadding: EdgeInsets.symmetric(
                    vertical: _textFieldVerticalPadding,
                    horizontal: 0,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  return null;
                },
              ),
              const Divider(height: 1, thickness: 0.5),
              TextFormField(
                controller: _bodyController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Compose email',
                  contentPadding: EdgeInsets.symmetric(
                    vertical: _textFieldVerticalPadding,
                    horizontal: 0,
                  ),
                ),
                maxLines: null,
                minLines: 15,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (_initialAttachmentsFromDraft.isNotEmpty) ...[
                Text(
                  "Attachments from draft:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryText,
                  ),
                ),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: List.generate(_initialAttachmentsFromDraft.length, (
                    index,
                  ) {
                    final attachment = _initialAttachmentsFromDraft[index];
                    return Chip(
                      avatar: Icon(
                        Icons.attach_file,
                        size: 16,
                        color: AppColors.secondaryIcon,
                      ),
                      label: Text(
                        attachment['name'] ?? 'file',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                      onDeleted:
                          () => _removeAttachment(index, isInitial: true),
                      backgroundColor: Colors.grey.shade200,
                    );
                  }),
                ),
                const SizedBox(height: 8),
              ],
              if (_attachments.isNotEmpty) ...[
                Text(
                  "New attachments:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryText,
                  ),
                ),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: List.generate(_attachments.length, (index) {
                    final file = _attachments[index];
                    return Chip(
                      avatar: Icon(
                        Icons.attach_file,
                        size: 16,
                        color: AppColors.secondaryIcon,
                      ),
                      label: Text(
                        file.name,
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                      onDeleted: () => _removeAttachment(index),
                      backgroundColor: Colors.grey.shade200,
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
