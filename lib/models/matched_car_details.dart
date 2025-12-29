class MatchedCarDetailResponse {
  final bool success;
  final List<MatchedCar> matchedCars;
  final int page;
  final int per_page;
  final int totalPages;

  MatchedCarDetailResponse({
    required this.success,
    required this.matchedCars,
    required this.page,
    required this.per_page,
    required this.totalPages,
  });

  factory MatchedCarDetailResponse.fromJson(Map<String, dynamic> json) {
    return MatchedCarDetailResponse(
      success: json["success"] ?? false,
      matchedCars: (json["matched_cars"] as List<dynamic>?)
          ?.map((e) => MatchedCar.fromJson(e))
          .toList() ??
          [],
      page: json["page"] ?? 1,
      per_page: json["per_page"] ??10,
      totalPages: json["total_pages"] ?? 1,
    );
  }
}

class MatchedCar {
  final String regNo;
  final String carMake;
  final String? status;
  final String? batchNumber;
  final String? createdAt;
  final List<SearchHistory> searchHistory;

  MatchedCar({
    required this.regNo,
    required this.carMake,
    this.status,
    this.batchNumber,
    this.createdAt,
    required this.searchHistory,
  });

  factory MatchedCar.fromJson(Map<String, dynamic> json) {
    return MatchedCar(
      regNo: json["reg_no"] ?? "",
      carMake: json["car_make"] ?? "",
      status: json["status"],
      batchNumber: json["batch_number"],
      createdAt: json["created_at"],
      searchHistory: (json["search_history"] as List<dynamic>?)
          ?.map((e) => SearchHistory.fromJson(e))
          .toList() ??
          [],
    );
  }
}

class SearchHistory {
  final String regNo;
  final String? locationDetails;
  final String? notes;
  final String? searchedAt;

  SearchHistory({
    required this.regNo,
    this.locationDetails,
    this.notes,
    this.searchedAt,
  });

  factory SearchHistory.fromJson(Map<String, dynamic> json) {
    return SearchHistory(
      regNo: json["reg_no"] ?? "",
      locationDetails: json["location_details"],
      notes: json["notes"],
      searchedAt: json["searched_at"],
    );
  }
}
