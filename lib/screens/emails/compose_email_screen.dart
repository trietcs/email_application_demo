import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/models/email_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;
  bool _isSavingDraft = false;

  String _editingDraftId = '';

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    String formatRecipientForToField(Map<String, String> recipient) {
      return recipient['displayName'] ?? recipient['userId'] ?? '';
    }

    if (widget.replyToEmail != null) {
      final originalEmail = widget.replyToEmail!;
      _toController.text = originalEmail.senderName;
      _subjectController.text =
          originalEmail.subject.toLowerCase().startsWith('re:')
              ? originalEmail.subject
              : 'Re: ${originalEmail.subject}';
      _bodyController.text =
          '\n\n\n--- Thư gốc vào lúc ${_formatDateTimeForQuote(originalEmail.time)} ---\nTừ: ${originalEmail.senderName}\nChủ đề: ${originalEmail.subject}\n\n${originalEmail.body}';
      _bodyController.selection = TextSelection.fromPosition(
        const TextPosition(offset: 0),
      );
    } else if (widget.forwardEmail != null) {
      final originalEmail = widget.forwardEmail!;
      _subjectController.text =
          originalEmail.subject.toLowerCase().startsWith('fw:')
              ? originalEmail.subject
              : 'Fw: ${originalEmail.subject}';
      _bodyController.text =
          '\n\n\n--- Thư chuyển tiếp ---\nTừ: ${originalEmail.senderName}\nNgày: ${_formatDateTimeForQuote(originalEmail.time)}\nChủ đề: ${originalEmail.subject}\n\n${originalEmail.body}';
    } else if (widget.draftToEdit != null) {
      final draft = widget.draftToEdit!;
      _toController.text = draft.to
          .map((r) => formatRecipientForToField(r))
          .where((s) => s.isNotEmpty)
          .join(', ');
      _subjectController.text = draft.subject;
      _bodyController.text = draft.body;
      _editingDraftId = draft.id;
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

  Future<void> _sendEmail(User currentUser) async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isSending = true);

    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final String senderId = currentUser.uid;
    final String senderDisplayName =
        currentUser.displayName?.isNotEmpty == true
            ? currentUser.displayName!
            : (currentUser.email?.split('@')[0] ?? 'Người gửi');

    final List<String> recipientContacts =
        _toController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    List<Map<String, String>> recipientsData = [];
    bool allRecipientsFound = true;

    for (String contact in recipientContacts) {
      final recipientUserInfo = await firestoreService.findUserByContactInfo(
        contact,
      );
      if (recipientUserInfo != null &&
          recipientUserInfo['userId'] != null &&
          recipientUserInfo['displayName'] != null) {
        recipientsData.add({
          'userId': recipientUserInfo['userId']!,
          'displayName': recipientUserInfo['displayName']!,
        });
      } else {
        allRecipientsFound = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không tìm thấy người nhận: $contact')),
          );
        }
        break;
      }
    }

    if (!allRecipientsFound || recipientsData.isEmpty) {
      if (mounted && recipientsData.isEmpty && allRecipientsFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập ít nhất một người nhận hợp lệ.'),
          ),
        );
      }
      if (mounted) setState(() => _isSending = false);
      return;
    }

    try {
      await firestoreService.sendEmail(
        senderId: senderId,
        senderDisplayName: senderDisplayName,
        recipients: recipientsData,
        subject: _subjectController.text,
        body: _bodyController.text,
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
        ).showSnackBar(const SnackBar(content: Text('Đã gửi thư!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi thư thất bại: ${e.toString()}')),
        );
      }
      print("Error sending email: $e");
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _saveDraft(User currentUser) async {
    if (!mounted) return;
    if (_toController.text.isEmpty &&
        _subjectController.text.isEmpty &&
        _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có nội dung để lưu nháp.')),
      );
      return;
    }

    setState(() => _isSavingDraft = true);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Lưu trước
    final String senderId = currentUser.uid;
    final String senderDisplayName =
        currentUser.displayName?.isNotEmpty == true
            ? currentUser.displayName!
            : (currentUser.email?.split('@')[0] ?? 'Người gửi');

    final List<String> recipientContacts =
        _toController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    List<Map<String, String>> recipientsDataForDraft = [];
    for (String contact in recipientContacts) {
      final recipientUserInfo = await firestoreService.findUserByContactInfo(
        contact,
      );
      if (recipientUserInfo != null) {
        recipientsDataForDraft.add({
          'userId': recipientUserInfo['userId']!,
          'displayName': recipientUserInfo['displayName']!,
        });
      } else {
        recipientsDataForDraft.add({'userId': '', 'displayName': contact});
      }
    }

    try {
      String? savedDraftId;
      // Nếu đang chỉnh sửa nháp, sử dụng updateDraft
      if (_editingDraftId.isNotEmpty) {
        await firestoreService.updateDraft(
          userId: senderId,
          draftId: _editingDraftId,
          senderDisplayName: senderDisplayName,
          recipients: recipientsDataForDraft,
          subject: _subjectController.text,
          body: _bodyController.text,
        );
      } else {
        // Gọi API saveDraft để lưu nháp mới
        savedDraftId = await firestoreService.saveDraft(
          userId: senderId,
          senderDisplayName: senderDisplayName,
          recipients: recipientsDataForDraft,
          subject: _subjectController.text,
          body: _bodyController.text,
        );
      }

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Đã lưu vào thư nháp')),
        );
        Navigator.pop(context, false); // Quay lại mà không làm mới danh sách
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Lưu nháp thất bại: ${e.toString()}')),
        );
      }
      print("Error saving draft: $e");
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Soạn thư')),
        body: const Center(child: Text('Vui lòng đăng nhập để soạn thư.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soạn thư'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Hủy',
          onPressed: () async {
            // Kiểm tra nếu có thay đổi so với trạng thái ban đầu
            bool hasChanges =
                _toController.text.isNotEmpty ||
                _subjectController.text.isNotEmpty ||
                _bodyController.text.isNotEmpty;

            if (widget.replyToEmail != null ||
                widget.forwardEmail != null ||
                widget.draftToEdit != null) {
              hasChanges =
                  _toController.text != widget.replyToEmail?.senderName &&
                  _toController.text !=
                      (widget.draftToEdit?.to
                              .map((r) => r['displayName'])
                              .where((s) => s?.isNotEmpty ?? false)
                              .join(', ') ??
                          '') &&
                  _subjectController.text != widget.replyToEmail?.subject &&
                  _subjectController.text != widget.forwardEmail?.subject &&
                  _subjectController.text != widget.draftToEdit?.subject &&
                  _bodyController.text != widget.replyToEmail?.body &&
                  _bodyController.text != widget.forwardEmail?.body &&
                  _bodyController.text != widget.draftToEdit?.body;
            }

            if (hasChanges) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Xác nhận'),
                      content: const Text(
                        'Bạn có muốn hủy email này không? Nội dung sẽ không được lưu.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Không'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );
              if (confirmed != true) return;
            }
            Navigator.pop(context, false);
          },
        ),
        actions: [
          if (_isSavingDraft || _isSending)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.drafts_outlined),
              tooltip: 'Lưu nháp',
              onPressed: () => _saveDraft(currentUser),
            ),
            IconButton(
              icon: const Icon(Icons.send_outlined),
              tooltip: 'Gửi',
              onPressed: () => _sendEmail(currentUser),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _toController,
                decoration: const InputDecoration(
                  labelText: 'Đến (SĐT/Email, cách nhau bởi dấu phẩy)',
                  hintText: 'ví dụ: 090xxxxxxx, 091xxxxxxx',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập ít nhất một người nhận.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Chủ đề',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập chủ đề.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  hintText: 'Viết thư của bạn ở đây...',
                ),
                maxLines: null,
                minLines: 10,
                keyboardType: TextInputType.multiline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập nội dung thư.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
