// lib/Notification/notification_model.dart

class NotificationPermissions {
  final bool canEdit;
  final bool canCancel;
  final bool canApprove;
  final bool canDelete;

  NotificationPermissions({
    this.canEdit = false,
    this.canCancel = false,
    this.canApprove = false,
    this.canDelete = false,
  });

  factory NotificationPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return NotificationPermissions();
    return NotificationPermissions(
      canEdit: json['canEdit'] ?? false,
      canCancel: json['canCancel'] ?? false,
      canApprove: json['canApprove'] ?? false,
      canDelete: json['canDelete'] ?? false,
    );
  }
}

class NotificationModel {
  final int id; // ปรับเป็น String หาก Backend ส่งเป็น UUID
  final String title;
  final String message;
  final String type; // เช่น 'ROOM', 'VEHICLE', 'SYSTEM'
  final String entityType; // เช่น 'BOOKING_ROOM'
  final String entityId;
  final bool isRead;
  final DateTime createdAt;
  final NotificationPermissions? permissions;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.isRead,
    required this.createdAt,
    this.permissions,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? json['content'] ?? '',
      type: json['type'] ?? 'SYSTEM',
      entityType: json['entityType'] ?? json['entity_type'] ?? '',
      entityId:
          json['entityId']?.toString() ?? json['entity_id']?.toString() ?? '',
      isRead:
          json['isRead'] == true ||
          json['isRead'] == 1 ||
          json['is_read'] == true ||
          json['is_read'] == 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : (json['created_at'] != null
                ? DateTime.parse(json['created_at'].toString())
                : DateTime.now()),
      permissions: json['permissions'] != null
          ? NotificationPermissions.fromJson(json['permissions'])
          : null,
    );
  }
}
