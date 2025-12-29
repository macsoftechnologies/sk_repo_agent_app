class CarActionModel {
  final int id;
  final int agentId;
  final String regNo;
  final String? carMake;
  final String? carModal;
  final String? status;
  final int? assignedAgentId;
  final String? assignedAgentName;
  final String? gpsLocation;
  final String? locationDetails;
  final String? notes;
  final String? photo;
  final int found;
  final int? carId;
  final String? searchedAt;

  CarActionModel({
    required this.id,
    required this.agentId,
    required this.regNo,
    this.carMake,
    this.carModal,
    this.status,
    this.assignedAgentId,
    this.assignedAgentName,
    this.gpsLocation,
    this.locationDetails,
    this.notes,
    this.photo,
    required this.found,
    this.carId,
    this.searchedAt,
  });

  factory CarActionModel.fromJson(Map<String, dynamic> json) {
    return CarActionModel(
      id: _parseInt(json['id']),
      agentId: _parseInt(json['agent_id']),
      regNo: _parseString(json['reg_no']),
      carMake: _parseStringNullable(json['car_make']),
      carModal: _parseStringNullable(json['car_modal']),
      status: _parseStringNullable(json['status']),
      assignedAgentId: _parseIntNullable(json['assigned_agent_id']),
      assignedAgentName: _parseStringNullable(json['assigned_agent_name']),
      gpsLocation: _parseStringNullable(json['gps_location']),
      locationDetails: _parseStringNullable(json['location_details']),
      notes: _parseStringNullable(json['notes']),
      photo: _parseStringNullable(json['photo']),
      found: _parseInt(json['found']),
      carId: _parseIntNullable(json['car_id']),
      searchedAt: _parseStringNullable(json['searched_at']),
    );
  }

  // Helper methods for safe parsing
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String? _parseStringNullable(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    final str = value.toString();
    return str.isEmpty ? null : str;
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "agent_id": agentId,
      "reg_no": regNo,
      "car_make": carMake,
      "car_modal": carModal,
      "status": status,
      "assigned_agent_id": assignedAgentId,
      "assigned_agent_name": assignedAgentName,
      "gps_location": gpsLocation,
      "location_details": locationDetails,
      "notes": notes,
      "photo": photo,
      "found": found,
      "car_id": carId,
      "searched_at": searchedAt,
    };
  }
}