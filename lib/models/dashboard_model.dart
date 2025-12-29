class DashboardModel {
  final String isPaid;
  final int daysLeft;
  final int recovered;
  final int completed;
  final String expiryDate;
  final Stats stats;
  final List<AssignedBatch> assignedBatches;
  final List<Notification> notifications;
  final String welcomeName;

  DashboardModel({
    required this.isPaid,
    required this.daysLeft,
    required this.recovered,
    required this.completed,
    required this.expiryDate,
    required this.stats,
    required this.assignedBatches,
    required this.notifications,
    required this.welcomeName,
  });
  String get formattedExpiry {
    try {
      final dt = DateTime.parse(expiryDate);
      return "${dt.day.toString().padLeft(2, '0')}-"
          "${_month(dt.month)}-${dt.year}";
    } catch (_) {
      return expiryDate;
    }
  }

  String _month(int m) {
    const months = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return months[m-1];
  }


  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      isPaid: json["is_paid"]?.toString() ?? "0",
      daysLeft: json["days_left"] == null ? 0 : int.parse(json["days_left"].toString()),
      recovered: json["stats"]["recovered"] == null ? 0 : int.parse(json["stats"]["recovered"].toString()),
      completed: json["stats"]["completed"] == null ? 0 : int.parse(json["stats"]["completed"].toString()),
      expiryDate: json["expiry_date"]?.toString() ?? "--",
      stats: Stats.fromJson(json["stats"] ?? {}),
      assignedBatches: (json["assigned_batches"] as List<dynamic>?)
          ?.map((item) => AssignedBatch.fromJson(item))
          .toList() ?? [],
      notifications: (json["notifications"] as List<dynamic>?)
          ?.map((item) => Notification.fromJson(item))
          .toList() ?? [],
      welcomeName: json["welcome_name"]?.toString() ?? "",
    );
  }
}

class Stats {
  final int totalAssigned;
  final int unverified;
  final int recovered;
  final int completed;

  Stats({
    required this.totalAssigned,
    required this.unverified,
    required this.recovered,
    required this.completed,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalAssigned: json["total_assigned"] == null ? 0 : int.parse(json["total_assigned"].toString()),
      unverified: json["Unverified"] == null ? 0 : int.parse(json["Unverified"].toString()),
      recovered: json["recovered"] == null ? 0 : int.parse(json["recovered"].toString()),
      completed: json["completed"] == null ? 0 : int.parse(json["completed"].toString()),
    );
  }
}

class AssignedBatch {
  final String batchNumber;
  final int totalCars;
  final int assignedToMe;
  final int completedCars;

  AssignedBatch({
    required this.batchNumber,
    required this.totalCars,
    required this.assignedToMe,
    required this.completedCars,
  });

  factory AssignedBatch.fromJson(Map<String, dynamic> json) {
    return AssignedBatch(
      batchNumber: json["batch_number"]?.toString() ?? "",
      totalCars: json["total_cars"] == null ? 0 : int.parse(json["total_cars"].toString()),
      assignedToMe: json["assigned_to_me"] == null ? 0 : int.parse(json["assigned_to_me"].toString()),
      completedCars: json["completed_cars"] == null ? 0 : int.parse(json["completed_cars"].toString()),
    );
  }
}

class Notification {
  final String id;
  final String userId;
  final String message;
  final String type;
  final String batchNumber;
  final bool isRead;
  final String createdAt;
  final String? readAt;

  Notification({
    required this.id,
    required this.userId,
    required this.message,
    required this.type,
    required this.batchNumber,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json["id"]?.toString() ?? "",
      userId: json["user_id"]?.toString() ?? "",
      message: json["message"]?.toString() ?? "",
      type: json["type"]?.toString() ?? "",
      batchNumber: json["batch_number"]?.toString() ?? "",
      isRead: json["is_read"] == "1",
      createdAt: json["created_at"]?.toString() ?? "",
      readAt: json["read_at"]?.toString(),
    );
  }
}