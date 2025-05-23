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
  final String folder;

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
  });

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
    );
  }
}
