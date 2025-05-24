import 'package:cloud_firestore/cloud_firestore.dart';

class EmailData {
  final String id;
  final String senderName;
  final String senderEmail;
  final String subject;
  final String previewText;
  final String body;
  final String time;
  bool isRead;
  final List<Map<String, String>> to;
  final List<Map<String, String>>? cc;
  final List<Map<String, String>>? bcc;
  final String folder; // 'inbox', 'sent', 'drafts', 'trash'
  final List<Map<String, String>>? attachments;

  EmailData({
    required this.id,
    required this.senderName,
    this.senderEmail = '',
    required this.subject,
    required this.previewText,
    required this.body,
    required this.time,
    required this.isRead,
    required this.to,
    this.cc,
    this.bcc,
    this.folder = 'inbox',
    this.attachments,
  });

  factory EmailData.fromMap(Map<String, dynamic> map, String id) {
    return EmailData(
      id: id,
      senderName:
          map['senderName'] ??
          (map['from'] is Map
              ? map['from']['displayName'] ?? 'Unknown Sender'
              : 'Unknown Sender'),
      senderEmail:
          map['senderEmail'] ??
          (map['from'] is Map ? map['from']['userId'] ?? '' : ''),
      subject: map['subject'] ?? '',
      previewText:
          map['previewText'] ??
          (map['body'] != null && (map['body'] as String).length > 100
              ? (map['body'] as String).substring(0, 100)
              : map['body'] ?? ''),
      body: map['body'] ?? '',
      time:
          map['timestamp']?.toDate().toIso8601String() ??
          DateTime.now().toIso8601String(),
      isRead: map['isRead'] ?? false,
      to: List<Map<String, String>>.from(
        map['to']?.map((item) => Map<String, String>.from(item as Map)) ?? [],
      ),
      cc:
          map['cc'] != null
              ? List<Map<String, String>>.from(
                map['cc'].map((item) => Map<String, String>.from(item as Map)),
              )
              : [],
      bcc:
          map['bcc'] != null
              ? List<Map<String, String>>.from(
                map['bcc'].map((item) => Map<String, String>.from(item as Map)),
              )
              : [],
      folder: map['folder'] ?? 'inbox',
      attachments:
          map['attachments'] != null
              ? List<Map<String, String>>.from(
                map['attachments'].map(
                  (item) => Map<String, String>.from(item as Map),
                ),
              )
              : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderName': senderName,
      'senderEmail': senderEmail,
      'subject': subject,
      'previewText': previewText,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'to': to,
      'cc': cc,
      'bcc': bcc,
      'folder': folder,
      'attachments': attachments,
    };
  }

  EmailData copyWith({
    String? id,
    String? senderName,
    String? senderEmail,
    String? subject,
    String? previewText,
    String? body,
    String? time,
    bool? isRead,
    List<Map<String, String>>? to,
    List<Map<String, String>>? cc,
    List<Map<String, String>>? bcc,
    String? folder,
    List<Map<String, String>>? attachments,
  }) {
    return EmailData(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      subject: subject ?? this.subject,
      previewText: previewText ?? this.previewText,
      body: body ?? this.body,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      folder: folder ?? this.folder,
      attachments: attachments ?? this.attachments,
    );
  }
}
