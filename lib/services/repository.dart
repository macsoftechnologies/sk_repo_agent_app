// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:dio/dio.dart';

class Repository {
  static final Dio dio = Dio();

  static Options headerParameters() {
    Options options = Options(
      contentType: Headers.jsonContentType,
      headers: {},
    );
    dio.interceptors.add(LogInterceptor());
    return options;
  }

  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'Charset': 'utf-8',
    };
  }

  initializeInterceptors() {
    dio.interceptors.add(LogInterceptor());
  }

  static getErrorResponse() {
    return {
      "status": {
        "type": "Error",
        "message": "Server Errors",
        "code": 200,
        "error": "true",
      },
    };
  }


  // ignore: non_constant_identifier_names
  static Future<Map<String, dynamic>> FlexiblePostApi(dynamic endpoint, dynamic inputData) async {
  try {
    Options options;

    dynamic dataToSend;

    if (inputData is FormData) {
      // If inputData is FormData, send it as multipart/form-data
      options = Options(
        headers: {
          'Content-Type': 'multipart/form-data',
          'Accept': 'application/json',
        },
      );
      dataToSend = inputData;
    } else if (inputData is Map<String, dynamic>) {
      // If inputData is a Map, send as JSON
      options = Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      dataToSend = inputData;
    } else {
      throw Exception('Unsupported inputData type: ${inputData.runtimeType}');
    }

    Response response = await dio.post(
      endpoint,
      data: dataToSend,
      options: options,
    );

    if (response.data is String) {
      final decoded = jsonDecode(response.data);
      print('Decoded Response: $decoded');
      return decoded;
    } else if (response.data is Map<String, dynamic>) {
      print('Response is already a Map: ${response.data}');
      return response.data;
    } else {
      print('Unexpected response type: ${response.data.runtimeType}');
      throw Exception('Unexpected response format');
    }
  } on DioException catch (e) {
    if (e.response != null) {
      print('Error response data: ${e.response!.data}');
      print('Error response headers: ${e.response!.headers}');
      throw Exception('Dio Error: ${e.response!.data}');
    } else {
      print('Error sending request: $e');
      throw Exception('Dio Error: $e');
    }
  }
}


  
  // ignore: non_constant_identifier_names

 static Future<dynamic> getApiService(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      Response response = await dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      print('GET Response: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        print('GET Error Response: ${e.response!.data}');
        return e.response!.data;
      } else {
        print('GET Error (No Response): $e');
        return {"error": "Request failed"};
      }
    } catch (e) {
      print('Unexpected Error: $e');
      return {"error": "Unexpected error occurred"};
    }
  }




    static Future<dynamic> postApiService(dynamic endpoint, dynamic inputData) async {
      var formData = FormData.fromMap(inputData);
      try {
        Response response = await dio.post(
          endpoint, // Replace with your API endpoint
          data: formData,
        );
        print('Response: ${response.data}');

        return response.data;
      } on DioException catch (e) {
        if (e.response != null) {
          print('Error response data: ${e.response!.data}');
          print('Error response headers: ${e.response!.headers}');
          return e.toString();
        } else {
          print('Error sending request: $e');
          return e.toString();
        }
      }
    }


    static Future<Map<String, dynamic>> NewPostApiService(dynamic endpoint,Map<String, dynamic> inputData,) async {
  var formData = FormData.fromMap(inputData);

  try {
    Response response = await dio.post(
      endpoint,
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
      ),
    );

    // Ensure response.data is Map<String, dynamic>
    if (response.data is String) {

      final decoded = jsonDecode(response.data);
      print('Decoded Response: $decoded');
      return decoded;
    } else if (response.data is Map<String, dynamic>) {
      print('Response is already a Map: ${response.data}');
      return response.data;
    } else {
      // Handle unexpected type
      print('Unexpected response type: ${response.data.runtimeType}');
      throw Exception('Unexpected response format');
    }
  } on DioException catch (e) {
    if (e.response != null) {
      print('Error response data: ${e.response!.data}');
      print('Error response headers: ${e.response!.headers}');
      throw Exception('Dio Error: ${e.response!.data}');
    } else {
      print('Error sending request: $e');
      throw Exception('Dio Error: $e');
    }
  }
}


    static Future<dynamic> postApiRawService(dynamic endpoint, dynamic inputData) async {
    try {
      Response response = await dio.post(
        endpoint,
        data: json.encode(inputData),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      print('Response: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        print('Error response data: ${e.response!.data}');
        print('Error response headers: ${e.response!.headers}');
        return e.toString();
      } else {
        print('Error sending request: $e');
        return e.toString();
      }
    }
  }

  static Future<dynamic> postimagesApiService(dynamic endpoint, dynamic formData) async {
  
    try {
      Response response = await dio.post(
        endpoint, // Replace with your API endpoint
        data: formData,
      );
      print('Response: ${response.data}');

      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        print('Error response data: ${e.response!.data}');
        print('Error response headers: ${e.response!.headers}');
        return e;
      } else {
        print('Error sending request: $e');
        return e;
      }
    }
  }
}
