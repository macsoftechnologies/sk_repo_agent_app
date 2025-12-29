// car_search_model.dart
class CarSearchResponse {
  final bool success;
  final String code;
  final String message;
  final CarData? data;

  CarSearchResponse({
    required this.success,
    required this.code,
    required this.message,
    this.data,
  });

  factory CarSearchResponse.fromJson(Map<String, dynamic> json) {
    return CarSearchResponse(
      success: json['success'] ?? false,
      code: json['code'] ?? '',
      message: json['message'] ?? '',
      data: json['data'] != null ? CarData.fromJson(json['data']) : null,
    );
  }
}

class CarData {
  final String batchNumber;
  final String regNo;
  final String carMake;
  final String carModel;
  final String status;
  final String gpsLocation;
  final String? locationDetails;
  final String createdAt;
  final String updatedAt;

  CarData({
    required this.batchNumber,
    required this.regNo,
    required this.carMake,
    required this.carModel,
    required this.status,
    required this.gpsLocation,
    this.locationDetails,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CarData.fromJson(Map<String, dynamic> json) {
    return CarData(
      batchNumber: json['batch_number'] ?? '',
      regNo: json['reg_no'] ?? '',
      carMake: json['car_make'] ?? '',
      carModel: json['car_modal'] ?? '', // Note: API returns "car_modal"
      status: json['status'] ?? '',
      gpsLocation: json['gps_location'] ?? '',
      locationDetails: json['location_details'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'batch_number': batchNumber,
      'reg_no': regNo,
      'car_make': carMake,
      'car_modal': carModel,
      'status': status,
      'gps_location': gpsLocation,
      'location_details': locationDetails,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

// Global storage class
class SearchStorage {
  static CarData? _lastSearchResult;
  static String? _lastLocation;
  static String? _lastRegNo;

  static void storeSearchResult(CarData data, String location, String regNo) {
    _lastSearchResult = data;
    _lastLocation = location;
    _lastRegNo = regNo;
  }

  static CarData? getLastSearchResult() => _lastSearchResult;
  static String? getLastLocation() => _lastLocation;
  static String? getLastRegNo() => _lastRegNo;

  static void clear() {
    _lastSearchResult = null;
    _lastLocation = null;
    _lastRegNo = null;
  }
}