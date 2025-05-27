import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_application/models/email_folder.dart';

class EmailData {
  final String id;
  final Map<String, String?> from;
  final String subject;
  final String previewText;
  final String body;
  final String time;
  bool isRead;
  final bool isStarred;
  final List<String> labelIds;

  final List<Map<String, String>> to;
  final List<Map<String, String>>? cc;
  final List<Map<String, String>>? bcc;

  final EmailFolder folder;
  final EmailFolder? originalFolder;
  final List<Map<String, String>>? attachments;

  EmailData({
    required this.id,
    required this.from,
    required this.subject,
    required this.previewText,
    required this.body,
    required this.time,
    required this.isRead,
    this.isStarred = false,
    List<String>? labelIds,
    required this.to,
    this.cc,
    this.bcc,
    required this.folder,
    this.originalFolder,
    this.attachments,
  }) : this.labelIds = labelIds ?? [];

  String get senderName => from['displayName'] ?? 'Unknown Sender';
  String get senderUid => from['userId'] ?? '';
  String? get senderActualEmail => from['email'];

  @Deprecated('Use senderUid or senderActualEmail from the `from` map instead.')
  String get senderEmail => senderActualEmail ?? senderUid;

  factory EmailData.fromMap(Map<String, dynamic> map, String id) {
    Map<String, String?> parseParticipantMap(dynamic participantData) {
      if (participantData is Map) {
        return {
          'userId': participantData['userId'] as String?,
          'displayName': participantData['displayName'] as String?,
          'email': participantData['email'] as String?,
        };
      }
      return {'userId': null, 'displayName': 'Unknown', 'email': null};
    }

    List<Map<String, String>> parseRecipientList(dynamic listData) {
      if (listData == null || listData is! List) return [];
      return listData.map((item) {
        if (item is Map) {
          return {
            'userId': item['userId']?.toString() ?? '',
            'displayName': item['displayName']?.toString() ?? 'Unknown',
            'email': item['email']?.toString() ?? '',
          };
        }
        return {'userId': '', 'displayName': 'Invalid Recipient', 'email': ''};
      }).toList();
    }

    Map<String, String?> fromData;
    if (map['from'] is Map) {
      fromData = parseParticipantMap(map['from']);
    } else {
      fromData = {
        'userId': map['senderEmail'] as String?,
        'displayName': map['senderName'] as String?,
        'email':
            (map['senderEmail'] is String &&
                    (map['senderEmail'] as String).contains('@'))
                ? map['senderEmail'] as String
                : null,
      };
    }
    fromData['displayName'] ??= 'Unknown Sender';
    fromData['userId'] ??= '';

    return EmailData(
      id: id,
      from: fromData,
      subject: map['subject'] as String? ?? '',
      previewText:
          map['previewText'] as String? ??
          (map['body'] != null && (map['body'] as String).length > 100
              ? (map['body'] as String).substring(0, 100)
              : map['body'] as String? ?? ''),
      body: map['body'] as String? ?? '',
      time:
          map['timestamp'] is Timestamp
              ? (map['timestamp'] as Timestamp).toDate().toIso8601String()
              : (map['timestamp'] is String
                  ? map['timestamp'] as String
                  : DateTime.now().toIso8601String()),
      isRead: map['isRead'] as bool? ?? false,
      isStarred: map['isStarred'] as bool? ?? false,
      labelIds: List<String>.from(map['labelIds'] as List<dynamic>? ?? []),
      to: parseRecipientList(map['to']),
      cc: parseRecipientList(map['cc']),
      bcc: parseRecipientList(map['bcc']),
      folder: EmailFolder.fromName(map['folder'] as String? ?? 'inbox'),
      originalFolder:
          map['originalFolder'] != null
              ? EmailFolder.fromName(map['originalFolder'] as String)
              : null,
      attachments:
          map['attachments'] != null
              ? List<Map<String, String>>.from(
                (map['attachments'] as List<dynamic>).map(
                  (item) => Map<String, String>.from(item as Map? ?? {}),
                ),
              )
              : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'from': from,
      'subject': subject,
      'previewText': previewText,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'isStarred': isStarred,
      'labelIds': labelIds,
      'to': to,
      'cc': cc,
      'bcc': bcc,
      'folder': folder.folderName,
      'originalFolder': originalFolder?.folderName,
      'attachments': attachments,
    };
  }

  EmailData copyWith({
    String? id,
    Map<String, String?>? from,
    String? subject,
    String? previewText,
    String? body,
    String? time,
    bool? isRead,
    bool? isStarred,
    List<String>? labelIds,
    List<Map<String, String>>? to,
    List<Map<String, String>>? cc,
    List<Map<String, String>>? bcc,
    EmailFolder? folder,
    EmailFolder? originalFolder,
    List<Map<String, String>>? attachments,
    @Deprecated('Use `from` map parameter instead') String? senderName,
    @Deprecated('Use `from` map parameter for sender UID and email instead')
    String? senderEmail,
  }) {
    Map<String, String?> finalFrom = from ?? this.from;

    if (senderName != null || senderEmail != null) {
      finalFrom = {
        'displayName': senderName ?? this.from['displayName'],
        'userId': senderEmail ?? this.from['userId'],
        'email':
            (senderEmail != null && senderEmail.contains('@'))
                ? senderEmail
                : (from == null ? this.from['email'] : from['email']),
      };
    }

    return EmailData(
      id: id ?? this.id,
      from: finalFrom,
      subject: subject ?? this.subject,
      previewText: previewText ?? this.previewText,
      body: body ?? this.body,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
      labelIds: labelIds ?? this.labelIds,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      folder: folder ?? this.folder,
      originalFolder: originalFolder ?? this.originalFolder,
      attachments: attachments ?? this.attachments,
    );
  }
}
