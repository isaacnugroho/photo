import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:photo/data/model/page_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_oauth_rework/lib/token.dart';
import 'package:flutter_oauth_rework/lib/model/config.dart';
import 'package:flutter_oauth_rework/lib/flutter_auth.dart';
import 'package:flutter_oauth_rework/lib/oauth.dart';
import 'package:flutter_oauth_rework/lib/auth_code_information.dart';
import 'package:flutter_oauth_rework/lib/oauth_token.dart';
import 'package:flutter_oauth_rework/generated/i18n.dart';

class NetworkCommon {
  static final NetworkCommon _singleton = new NetworkCommon._internal();

  factory NetworkCommon() {
    return _singleton;
  }

  NetworkCommon._internal();

  final JsonDecoder _decoder = new JsonDecoder();

  dynamic decodeResp(d) {
    // ignore: cast_to_non_type
    if (d is Response) {
      final dynamic jsonBody = d.data;
      final statusCode = d.statusCode;

      if (statusCode < 200 || statusCode >= 300 || jsonBody == null) {
        throw new Exception("statusCode: $statusCode");
      }

      if (jsonBody is String) {
        return _decoder.convert(jsonBody);
      } else {
        return jsonBody;
      }
    } else {
      throw d;
    }
  }

  Page decodePage(d) {
    if (d is Response) {
      final statusCode = d.statusCode;

      if (statusCode < 200 || statusCode >= 300) {
        throw new Exception("statusCode: $statusCode");
      }
      Page page = new Page();
      if (d.headers["link"].isNotEmpty) {
        List<String> p = d.headers["Link"].toString().split(",");
        for (String item in p) {
          int index = item.indexOf("&per_pag") > 0
              ? item.indexOf("&per_pag")
              : item.indexOf(">");
          int number =
              int.parse(item.substring(item.indexOf("page=") + 5, index));
          if (item.contains("first")) {
            page.first = number;
          } else if (item.contains("prev")) {
            page.prev = number;
          } else if (item.contains("next")) {
            page.next = number;
          } else if (item.contains("last")) {
            page.last = number;
          }
        }
      }
      return page;
    } else {
      throw d;
    }
  }

  Dio get dio {
    Dio dio = new Dio();
    // Set default configs
    dio.options.baseUrl = 'https://api.unsplash.com/';
    dio.options.connectTimeout = 50000; //5s
    dio.options.receiveTimeout = 30000;
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (RequestOptions options) async {
      /// Do something before request is sent
      /// set the token
//      SharedPreferences prefs = await SharedPreferences.getInstance();
//      String token = prefs.getString('token');
//      if (token != null) {
      options.headers["Authorization"] =
          "Client-ID e993cde7a4d49aa482dd572dfca4dd27891fc573c4f5bed7f202e156e02b8e8e";
//      }

      print("Pre request:${options.method},${options.baseUrl}${options.path}");
      print("Pre request:${options.headers.toString()}");

      return options; //continue
    }, onResponse: (Response response) async {
      // Do something with response data
      final int statusCode = response.statusCode;
      if (statusCode == 200) {
        if (response.request.path == "login/") {
          final SharedPreferences prefs = await SharedPreferences.getInstance();

          /// login complete, save the token
          /// response data:
          /// {
          ///   "code": 0,
          ///   "data": Object,
          ///   "msg": "OK"
          ///  }
          final String jsonBody = response.data;
          final JsonDecoder _decoder = new JsonDecoder();
          final resultContainer = _decoder.convert(jsonBody);
          final int code = resultContainer['code'];
          if (code == 0) {
            final Map results = resultContainer['data'];
            prefs.setString("token", results["token"]);
            prefs.setInt("expired", results["expired"]);
          }
        }
      } else if (statusCode == 401) {
        /// token expired, re-login or refresh token
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        var username = prefs.getString("username");
        var password = prefs.getString("password");
        FormData formData = new FormData.from({
          "username": username,
          "password": password,
        });
        new Dio().post("login/", data: formData).then((resp) {
          final String jsonBody = response.data;
          final JsonDecoder _decoder = new JsonDecoder();
          final resultContainer = _decoder.convert(jsonBody);
          final int code = resultContainer['code'];
          if (code == 0) {
            final Map results = resultContainer['data'];
            prefs.setString("token", results["token"]);
            prefs.setInt("expired", results["expired"]);

            RequestOptions ro = response.request;
            ro.headers["Authorization"] = "Bearer ${prefs.getString('token')}";
            return ro;
          } else {
            throw Exception("Exception in re-login");
          }
        });
      }

      print(
          "Response From:${response.request.method},${response.request.baseUrl}${response.request.path}");
      print("Response From:${response.toString()}");
      return response; // continue
    }, onError: (DioError e) async {
      // Do something with response error
      if (e.response?.statusCode == 401) {
//        var authResp =
//            await new Dio().get(authorizationEndpoint, queryParameters: {
//          "client_id": identifier,
//          "redirect_uri": redirectUrl,
//          "response_type": "code",
//          "scope":
//              "public+read_user+write_user+read_photos+write_photos+write_likes+write_followers+read_collections+write_collections"
//        });
//        print(authResp??"err");
        Map<String, String> customParameters = {
          "scope":
              "public+read_user+write_user+read_photos+write_photos+write_likes+write_followers+read_collections+write_collections"
        };

        final OAuth flutterOAuth = new FlutterOAuth(new Config(
            authorizationEndpoint,
            tokenEndpoint,
            identifier,
            secret,
            redirectUrl,
            "code",
            parameters: customParameters));
        Token token = await flutterOAuth.performAuthorization();
        print(token.toString());
      }
      return e; //continue
    }));
    return dio;
  }
}

final authorizationEndpoint = "https://unsplash.com/oauth/authorize";
final tokenEndpoint = "https://unsplash.com/oauth/token";
final identifier =
    "e993cde7a4d49aa482dd572dfca4dd27891fc573c4f5bed7f202e156e02b8e8e";
final secret =
    "98647647615be9bee8a75473574b380829b7ddfb0f97efab0fd708cb8596b6b5";
final redirectUrl = "http://localhost:8080";
