import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'package:crypto/crypto.dart';

var token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2NzY1OGI2NDhmODA5NWU5ZGM1ZWYyYzciLCJlbWFpbCI6Inh4eXh4ZG1jYmtiayIsInJvbGUiOiJtZW1iZXIiLCJuYW1lIjoieHh5eHhkbWNiayIsInZlcnNpb24iOiIyLjIuMS4zLjMuNCIsImJ1aWxkVmVyc2lvbiI6IjQ1IiwicGxhdGZvcm0iOiJhbmRyb2lkIiwiaWF0IjoxNzY0OTM4OTA3LCJleHAiOjE3NjU1NDM3MDd9.7MCMKMHAUC2kDC6U6mPVG8XUUh0GslZe6kJX-RnoHts";

const uuid = Uuid();
final uuidV1 = uuid.v1();
final uuidV4 = uuid.v4();
final time = DateTime.now().millisecondsSinceEpoch.toString();
Map<String, String> runTimeValue = {};

Future<void> main() async {
  var json = jsonDecode(await File("bin/pica.json").readAsString());
  final action = "profile";
  final uri = json["${action}_uri"].toString().startsWith("/") ? json["api_uri"].toString() + json["${action}_uri"].toString() : json["${action}_uri"].toString();
  final method = json["${action}_method"].toString();
  runTimeValue["uri"] = uri;
  runTimeValue["method"] = method;
  var data = {};
  if (json["${action}_data"] != null) {
    data = decodeHeaderOrData(json, isHeader: false, bodyKey: "${action}_data");
  }
  var dio = Dio()..options = BaseOptions(
      headers: decodeHeaderOrData(json),
      responseType: ResponseType.plain
  );
  var res = switch(method) {
    "get" => await dio.get(uri,
        data: data
    ),
    "post" => await dio.post(uri,
        data: data
    ),
    _ => {}
  };
  if (res is Response<dynamic>) print(res.data);
}

Map<String, String> decodeHeaderOrData(Map<String, dynamic> json, {bool isHeader = true, String bodyKey = ""}) {
  var rawHeaderOrData = Map<String, dynamic>.from(json[isHeader ? 'header' : bodyKey]);
  var extra = json['extra'] ?? {};
  var settings = json['settings'] ?? {};

  Map<String, String> resolved = {};

  rawHeaderOrData.forEach((key, value) {
    if (!key.startsWith("^")) resolved[key] = resolveValue(value, json, extra, settings);
  });

  return resolved;
}

String resolveValue(dynamic value, Map<String, dynamic> json,
    Map<String, dynamic> extra, Map<String, dynamic> settings, {
      String? hintKey
    }) {


  if (value == null) return "";

  if (value is Map) {
    return executeMethod(value as Map<String, dynamic>, json, extra, settings);
  }

  if (value is List) {
    if (value.isNotEmpty && value.first is Map) {
      return executeMethodGroup(value.cast<Map<String, dynamic>>(),
          json, extra, settings);
    } else {
      return resolveSettings(value, settings, settingKey: hintKey);
    }
  }

  String str = value.toString();

  if (str.startsWith("*")) {
    final k = str.substring(1);
    final v = extra[k];
    return resolveValue(v, json, extra, settings, hintKey: k);
  }

  if (str.startsWith("&")) {
    var k = str.substring(1);
    return getConstants(k);
  }

  if (str.startsWith(r"$")) {
    var k = str.substring(1);
    return getRuntimeValue(k);
  }

  if (str.startsWith("@")) {
    var k = str.substring(1);

    if (k == "encryption") {
      return executeEncryption(json, extra, settings);
    }

    var target = json[k];

    if (target is List) {
      return resolveValue(target, json, extra, settings, hintKey: k);
    } else if (target is Map) {
      return executeMethod(target as Map<String, dynamic>, json, extra, settings);
    } else {
      return target?.toString() ?? "";
    }
  }

  return str;
}

String executeMethodGroup(
    List<Map<String, dynamic>> steps,
    Map<String, dynamic> json,
    Map<String, dynamic> extra,
    Map<String, dynamic> settings,
    ) {
  dynamic current;

  for (var step in steps) {
    current = executeMethod(step, json, extra, settings, input: current);
  }

  return current.toString();
}

String getConstants(String key) {
  return switch (key) {
    "uuid1" => uuidV1,
    "uuid4" => uuidV4,
    "time" => time,
    _ => ""
  };
}

String getRuntimeValue(String key) {
  return switch (key) {
    "token" => token,
    "uri" => runTimeValue["uri"] ?? "",
    "method" => runTimeValue["method"] ?? "",
    "user_name" => "xxyxxdmcbkbk",
    "password" => "lgb20080216",
    _ => ""
  };
}

dynamic executeMethod(Map<String, dynamic> method,
    Map<String, dynamic> json, Map<String, dynamic> extra, Map<String, dynamic> settings, {
dynamic input = "",
}) {
  var way = method['way'] as String;
  switch (way.substring(1)) {
    case "input":
      var value = method['value'].toString();
      return resolveValue(value, json, extra, settings);
    case "stringMerge":
      var values = method['values'] as List;
      return values
          .map((v) => resolveValue(v, json, extra, settings))
          .join("");
    case "lowerCase":
      return input.toString().toLowerCase();
    case "utf8.encode":
      return utf8.encode(input.toString());
    case "HMAC-SHA256":
      var secret = method["secret"].toString();
      var hmacSha256 = Hmac(sha256, utf8.encode(secret));
      return hmacSha256.convert(utf8.encode(input));
    case "replaceAll":
      var keys = method['keys'] as List;
      return input.replaceAll(keys[0], keys[1]);
    case "+":
      var key = method['key'] as int;
      return (int.parse(input) ~/ key).toString();
    case "-":
      var key = method['key'] as int;
      return (int.parse(input) ~/ key).toString();
    case "~/":
      var key = method['key'] as int;
      return (int.parse(input) ~/ key).toString();
    default:
      throw Exception("Unknown method: $way");
  }
}

String resolveSettings(
    List<dynamic> options,
    Map<String, dynamic> settings,
    {String? settingKey}
    ) {
  if (settingKey != null) {
    final conf = settings[settingKey];
    if (conf is Map && conf.containsKey("default")) {
      return conf["default"].toString();
    }
  }
  return options.isNotEmpty ? options.first.toString() : "";
}
String executeEncryption(
    Map<String, dynamic> json,
    Map<String, dynamic> extra,
    Map<String, dynamic> settings) {
  var steps = json["encryption_way"] as List<dynamic>;
  dynamic current;

  for (var step in steps) {
    var way = step["way"] as String;
    switch (way.substring(1)) {
      case "stringMerge":
        var values = step["values"] as List;
        current = values
            .map((v) => resolveValue(v, json, extra, settings))
            .join();
        break;

      case "lowerCase":
        current = current.toLowerCase();
        break;

      case "utf8.encode":
        current = utf8.encode(current);
        break;

      case "HMAC-SHA256":
        var secret = utf8.encode(step["secret"].toString());
        var hmacSha256 = Hmac(sha256, secret);
        if (current is List<int>) {
          current = hmacSha256.convert(current);
        } else if (current is String){
          var a = utf8.encode(current);
          current = hmacSha256.convert(a);
        }
        break;

      default:
        throw Exception("Unknown encryption step: $way");
    }
  }

  return current.toString();
}