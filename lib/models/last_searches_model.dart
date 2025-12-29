class LastSearchesResponse {
  final bool success;
  final String message;
  final List<LastSearchItem> data;

  LastSearchesResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory LastSearchesResponse.fromJson(Map<String, dynamic> json) {
    return LastSearchesResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List? ?? [])
          .map((e) => LastSearchItem.fromJson(e))
          .toList(),
    );
  }
}

class LastSearchItem {
  final String regNo;
  final int found;

  LastSearchItem({
    required this.regNo,
    required this.found,
  });

  factory LastSearchItem.fromJson(Map<String, dynamic> json) {
    return LastSearchItem(
      regNo: json['reg_no'] ?? '',
      found: int.tryParse(json['found'].toString()) ?? 0,
    );
  }

  bool get isFound => found == 1;
}
