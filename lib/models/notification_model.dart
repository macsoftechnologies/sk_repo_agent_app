// class NotificationModel {
//   final String id;
//   final String userId;
//   final String message;
//   final String type;
//   final String batchNumber;
//   bool isRead;
//   final String createdAt;
//   final String? readAt;
//
//   NotificationModel({
//     required this.id,
//     required this.userId,
//     required this.message,
//     required this.type,
//     required this.batchNumber,
//     required this.isRead,
//     required this.createdAt,
//     required this.readAt,
//   });
//
//   factory NotificationModel.fromJson(Map<String, dynamic> json) {
//     return NotificationModel(
//       id: json["id"].toString(),
//       userId: json["user_id"].toString(),
//       message: json["message"] ?? "",
//       type: json["type"] ?? "",
//       batchNumber: json["batch_number"] ?? "",
//       isRead: json["is_read"].toString() == "1",
//       createdAt: json["created_at"] ?? "",
//       readAt: json["read_at"],
//     );
//   }
// }
class NotificationModel {
  final String id;
  final String userId;
  final String message;
  final String type;
  final String batchNumber;
  bool isRead;
  final String createdAt;
  final String readAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.type,
    required this.batchNumber,
    required this.isRead,
    required this.createdAt,
    required this.readAt,
  });

  // Convert JSON to NotificationModel
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      batchNumber: json['batch_number']?.toString() ?? '',
      isRead: json['is_read']?.toString() == '1',
      createdAt: json['created_at']?.toString() ?? '',
      readAt: json['read_at']?.toString() ?? '',
    );
  }

  // Format date for display
  String get formattedCreatedAt => _formatDateTime(createdAt);
  String get formattedReadAt => _formatDateTime(readAt);

  String _formatDateTime(String dateTimeStr) {
    try {
      if (dateTimeStr.isEmpty || dateTimeStr.toLowerCase() == 'null') return '-';

      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // If within 24 hours, show relative time
      if (difference.inHours < 24) {
        if (difference.inHours > 0) {
          return '${difference.inHours}h ago';
        } else if (difference.inMinutes > 0) {
          return '${difference.inMinutes}m ago';
        } else {
          return 'Just now';
        }
      }

      // Otherwise show date in dd/MM/yyyy format
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  // Convert to Map for API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'message': message,
      'type': type,
      'batch_number': batchNumber,
      'is_read': isRead ? '1' : '0',
      'created_at': createdAt,
      'read_at': readAt,
    };
  }
}