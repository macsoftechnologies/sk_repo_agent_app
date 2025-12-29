class ProfileModel {
  final String adminId;
  final String adminName;
  final String icNo;
  final String email;
  final String mobileNumber;
  final String roleId;
  final String isPaid;
  final String photo;
  final String idProof;
  final String joiningDate;
  final String address;
  final String status;

  ProfileModel({
    required this.adminId,
    required this.adminName,
    required this.icNo,
    required this.email,
    required this.mobileNumber,
    required this.roleId,
    required this.isPaid,
    required this.photo,
    required this.idProof,
    required this.joiningDate,
    required this.address,
    required this.status,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      adminId: json["admin_id"] ?? "",
      adminName: json["admin_name"] ?? "",
      icNo: json["ic_no"] ?? "",
      email: json["email"] ?? "",
      mobileNumber: json["mobile_number"] ?? "",
      roleId: json["role_id"] ?? "",
      isPaid: json["is_paid"] ?? "",
      photo: json["photo"] ?? "",
      idProof: json["id_proof"] ?? "",
      joiningDate: json["joining_date"] ?? "",
      address: json["address"] ?? "",
      status: json["status"] ?? "",
    );
  }
}
