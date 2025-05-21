class EmailData {
  final String id;
  final String senderName;
  final String subject;
  final String previewText;
  final String body;
  final String time;
  final bool isRead;
  final List<Map<String, String>> to;

  EmailData({
    required this.id,
    required this.senderName,
    required this.subject,
    required this.previewText,
    required this.body,
    required this.time,
    required this.isRead,
    required this.to,
  });
}