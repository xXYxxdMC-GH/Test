import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'package:crypto/crypto.dart';

var token = "";

final uuid = Uuid();

Future<void> main() async {
  var json = jsonDecode(await File("bin/pica.json").readAsString());
  var header = decodeHeader(json);
  var res = Dio().post("https://picaapi.picacomic.com/auth/sign-in", options: Options(headers: header),

  );
  print(res);
}

Map<String, String> decodeHeader(Map<String, dynamic> json) {
  var rawHeader = Map<String, dynamic>.from(json['header']);
  var extra = json['extra'] ?? {};
  var settings = json['settings'] ?? {};

  Map<String, String> resolved = {};

  rawHeader.forEach((key, value) {
    if (!key.startsWith("^")) resolved[key] = resolveValue(value, json, extra, settings);
  });

  return resolved;
}

String resolveValue(dynamic value, Map<String, dynamic> json,
    Map<String, dynamic> extra, Map<String, dynamic> settings, {
      String? hintKey,
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

  if (str.startsWith("\$")) {
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

  // 普通常量
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


/// 常量解析
String getConstants(String key) {
  return switch (key) {
    "uuid1" => uuid.v1(),
    "uuid4" => uuid.v4(),
    "time" => DateTime.now().millisecondsSinceEpoch.toString(),
    _ => ""
  };
}

/// 模拟运行时变量
String getRuntimeValue(String key) {
  return switch (key) {
    "token" => token,
    "uri" => "/auth/sign-in",
    "method" => "POST",
    _ => ""
  };
}

dynamic executeMethod(Map<String, dynamic> method,
    Map<String, dynamic> json, Map<String, dynamic> extra, Map<String, dynamic> settings, {
dynamic input = "",
}) {
  var way = method['way'];
  if (way.toString().startsWith(r"$")) return getConstants(way.toString().substring(1));
  switch (way) {
    case "#stringMerge":
      var values = method['values'] as List;
      return values
          .map((v) => resolveValue(v, json, extra, settings))
          .join("");
    case "#lowerCase":
      return input.toString().toLowerCase();
    case "#utf8.encode":
      return utf8.encode(input.toString());
    case "#HMAC-SHA256":
      var secret = method["secret"].toString();
      var hmacSha256 = Hmac(sha256, utf8.encode(secret));
      return hmacSha256.convert(input as List<int>);
    case "#toString":
      return input.toString();
    case "#replaceAll":
      var keys = method['keys'] as List;
      return input.replaceAll(keys[0], "");
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
    var way = step["way"];
    switch (way) {
      case "#stringMerge":
        var values = step["values"] as List;
        current = values
            .map((v) => resolveValue(v, json, extra, settings))
            .join("");
        break;

      case "#lowerCase":
        current = current.toString().toLowerCase();
        break;

      case "#utf8.encode":
        current = utf8.encode(current.toString());
        break;

      case "#HMAC-SHA256":
        var secret = step["secret"].toString();
        var hmacSha256 = Hmac(sha256, utf8.encode(secret));
        current = hmacSha256.convert(current as List<int>);
        break;

      case "#toString":
        current = current.toString();
        break;

      default:
        throw Exception("Unknown encryption step: $way");
    }
  }

  return current.toString();
}


