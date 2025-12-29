class CarMasterResponse {
  final bool status;
  final String message;
  final CarMasterData data;

  CarMasterResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory CarMasterResponse.fromJson(Map<String, dynamic> json) {
    return CarMasterResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: CarMasterData.fromJson(json['data'] ?? {}),
    );
  }
}

class CarMasterData {
  final List<CarMasterModel> cars;
  final int totalCars;

  CarMasterData({
    required this.cars,
    required this.totalCars,
  });

  factory CarMasterData.fromJson(Map<String, dynamic> json) {
    final carsList = json['cars'] as List? ?? [];
    return CarMasterData(
      cars: carsList.map((car) => CarMasterModel.fromJson(car)).toList(),
      totalCars: CarMasterModel._parseInt(json['total_cars']),
    );
  }
}

class CarMasterModel {



  final int carId;
  final String batchNumber;
  final String regNo;
  final String? carMake; // Can be null
  final String? carModal; // Can be null
  final String? status; // Can be null
  final String? assignedAgentName; // Can be null
  final int? assignedAgentId; // Can be null
  final String? gpsLocation; // Can be null
  final String? locationDetails; // Can be null
  final String? photo; // Already nullable, good
  final String? notes; // Can be null
  final String? createdAt; // Can be null
  final String? updatedAt; // Can be null
  final int? createdBy; // Can be null
  final int? updatedBy; // Can be null

  CarMasterModel({
    required this.carId,
    required this.batchNumber,
    required this.regNo,
    this.carMake,
    this.carModal,
    this.status,
    this.assignedAgentName,
    this.assignedAgentId,
    this.gpsLocation,
    this.locationDetails,
    this.photo,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory CarMasterModel.fromJson(Map<String, dynamic> json) {
    return CarMasterModel(
      carId: _parseInt(json['car_id']),
      batchNumber: _parseString(json['batch_number']),
      regNo: _parseString(json['reg_no']),
      carMake: _parseStringNullable(json['car_make']),
      carModal: _parseStringNullable(json['car_modal']),
      status: _parseStringNullable(json['status']),
      assignedAgentName: _parseStringNullable(json['assigned_agent_name']),
      assignedAgentId: _parseIntNullable(json['assigned_agent_id']),
      gpsLocation: _parseStringNullable(json['gps_location']),
      locationDetails: _parseStringNullable(json['location_details']),
      photo: _parseStringNullable(json['photo']),
      notes: _parseStringNullable(json['notes']),
      createdAt: _parseStringNullable(json['created_at']),
      updatedAt: _parseStringNullable(json['updated_at']),
      createdBy: _parseIntNullable(json['created_by']),
      updatedBy: _parseIntNullable(json['updated_by']),
    );
  }

  // Helper methods for safe parsing (reuse from previous model or define here)
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      if (value.isEmpty) return 0;
      return int.tryParse(value) ?? 0;
    }
    if (value is double) return value.toInt();
    return 0;
  }

  static int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      if (value.isEmpty) return null;
      return int.tryParse(value);
    }
    if (value is double) return value.toInt();
    return null;
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String? _parseStringNullable(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    final str = value.toString();
    return str.isEmpty ? null : str;
  }

  Map<String, dynamic> toMap() {
    return {
      "car_id": carId,
      "batch_number": batchNumber,
      "reg_no": regNo,
      "car_make": carMake,
      "car_modal": carModal,
      "status": status,
      "assigned_agent_name": assignedAgentName,
      "assigned_agent_id": assignedAgentId,
      "gps_location": gpsLocation,
      "location_details": locationDetails,
      "photo": photo,
      "notes": notes,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "created_by": createdBy,
      "updated_by": updatedBy,
    };
  }

  // Optional: Add copyWith method for immutability
  CarMasterModel copyWith({
    int? carId,
    String? batchNumber,
    String? regNo,
    String? carMake,
    String? carModal,
    String? status,
    String? assignedAgentName,
    int? assignedAgentId,
    String? gpsLocation,
    String? locationDetails,
    String? photo,
    String? notes,
    String? createdAt,
    String? updatedAt,
    int? createdBy,
    int? updatedBy,
  }) {
    return CarMasterModel(
      carId: carId ?? this.carId,
      batchNumber: batchNumber ?? this.batchNumber,
      regNo: regNo ?? this.regNo,
      carMake: carMake ?? this.carMake,
      carModal: carModal ?? this.carModal,
      status: status ?? this.status,
      assignedAgentName: assignedAgentName ?? this.assignedAgentName,
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      locationDetails: locationDetails ?? this.locationDetails,
      photo: photo ?? this.photo,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}