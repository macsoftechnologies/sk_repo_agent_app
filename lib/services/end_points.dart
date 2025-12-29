class EndPoints {
  //base url
  static const String baseUrlLocal = "https://macsof.in/carmanagment/api/";
  //Partial Api End Points

  static const String baseUrl="https://www.repomaster33.com/repo/api/";

  static const String loginApi = "${baseUrl}agent-login";
  static const String agentSearchedCarsApi = "${baseUrl}search_data";
  static const String verifiedCarsApi = "${baseUrl}verified-cars";
  static const String matchedCarsApi = "${baseUrl}agent_matched_dashboard";
  static const String profileApi = "${baseUrl}agent/profile";
  static const String changePasswordApi = "${baseUrl}agent/profile/update_password";
  static const String logoutApi = "${baseUrl}logout";

  static const String allNotificationsApi = "${baseUrl}fetch-all-notifications";
  static const String unreadNotificationsApi = "${baseUrl}fetch-notifications";
  static const String markAsReadNotificationsApi = "${baseUrl}mark-notification";
  static const String dashboardApi = "${baseUrl}agent_dashboard_api";
  static const String getLocationApi = "${baseUrl}get_location_api";
  static const String searchCarsApi = "${baseUrl}car_search_api";
  static const String updateCarsApi = "${baseUrl}update_car_details";
  static const String last3SearchedCarsApi = "${baseUrl}last_three_searches_api";
  static const String uploadOldCarsApi = "${baseUrl}upload_car_file";
  static const String deleteAgentCarSearch = "${baseUrl}delete_agent_car_search";
  static const String uploadCarSearches = "${baseUrl}post_offline_searches";
  //deleteAgentCarSearch

  //getallcars
  static const String getAllCarsMainData = "${baseUrl}getallcars";
  static const String getAgentSearchMainData = "${baseUrl}getsearchedcars";

  // New sync endpoints (add these)
  static const String syncMasterCarsEndpoint = "${baseUrl}sync_modified_cars";
  static const String getMasterUpdateCars = "${baseUrl}get_modified_cars_api";
  static const String syncActionsEndpoint = "${baseUrl}post_offline_searches";

  // Optional: Add more endpoints as needed
  static const String getLastSyncTime = "https://yourapi.com/api/get-last-sync";
}