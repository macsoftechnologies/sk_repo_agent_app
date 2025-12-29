// lib/models/verified_car.dart
import 'dart:convert';

class VerifiedCar {
  final int sNo;
  final String batchNumber;
  final String regNo;
  final String status;
  final String gpsLocation;
  final String locationDetails;
  final String updatedAt;

  VerifiedCar({
    required this.sNo,
    required this.batchNumber,
    required this.regNo,
    required this.status,
    required this.gpsLocation,
    required this.locationDetails,
    required this.updatedAt,
  });

  factory VerifiedCar.fromJson(Map<String, dynamic> json) {
    return VerifiedCar(
      sNo: json['s_no'] is int ? json['s_no'] : int.tryParse("${json['s_no']}") ?? 0,
      batchNumber: json['batch_number']?.toString() ?? '',
      regNo: json['reg_no']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      gpsLocation: json['gps_location']?.toString() ?? '',
      locationDetails: json['location_details']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  static List<VerifiedCar> listFromJson(dynamic jsonList) {
    if (jsonList == null) return [];
    final list = <VerifiedCar>[];
    for (final item in jsonList) {
      if (item is Map<String, dynamic>) {
        list.add(VerifiedCar.fromJson(item));
      } else if (item is Map) {
        list.add(VerifiedCar.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return list;
  }

  Map<String, dynamic> toJson() {
    return {
      's_no': sNo,
      'batch_number': batchNumber,
      'reg_no': regNo,
      'status': status,
      'gps_location': gpsLocation,
      'location_details': locationDetails,
      'updated_at': updatedAt,
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}
