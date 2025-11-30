import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'package:crypto/crypto.dart';

var token = "";

const uuid = Uuid();
final uuidV1 = uuid.v1();
final uuidV4 = uuid.v4();

Future<void> main() async {
  var json = jsonDecode(await File("bin/pica.json").readAsString());
  var header = decodeHeader(json);
  var data = {
    "email": "xxyxxdmcbkbk",
    "password": "lgb20080216"
  };
  var dio = Dio();
  //print(getHeaders("post", token, "auth/sign-in"));
  //print(header);
  dio.options = BaseOptions(headers: header..addAll({"content-length": data.toString().length.toString()}), responseType: ResponseType.plain, receiveDataWhenStatusError: true,);
  var res = await dio.post("https://picaapi.picacomic.com/auth/sign-in",
    options: Options(
      responseType: ResponseType.plain,
      validateStatus: (i) {
        return i == 200 || i == 400 || i == 401;
      },
    ),
    data: data
  );
  print(res.data);
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
    "time" => DateTime.now().millisecondsSinceEpoch.toString(),
    _ => ""
  };
}

String getRuntimeValue(String key) {
  return switch (key) {
    "token" => token,
    "uri" => "auth/sign-in",
    "method" => "POST",
    _ => ""
  };
}

dynamic executeMethod(Map<String, dynamic> method,
    Map<String, dynamic> json, Map<String, dynamic> extra, Map<String, dynamic> settings, {
dynamic input = "",
}) {
  var way = method['way'];
  if (way.toString().startsWith(r"&")) return getConstants(way.toString().substring(1));
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
      return hmacSha256.convert(utf8.encode(input));
    case "#replaceAll":
      var keys = method['keys'] as List;
      return input.replaceAll(keys[0], keys[1]);
    case "#~/":
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
    var way = step["way"];
    switch (way) {
      case "#stringMerge":
        var values = step["values"] as List;
        current = values
            .map((v) => resolveValue(v, json, extra, settings))
            .join();
        break;

      case "#lowerCase":
        current = current.toLowerCase();
        break;

      case "#utf8.encode":
        current = utf8.encode(current);
        break;

      case "#HMAC-SHA256":
        var secret = utf8.encode(r'~d}$Q7$eIni=V)9\RK/P.RM4;9[7|@/CA}b~OW!3?EV`:<>M7pddUBL5n|0/*Cn');
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

var apiKey = "C69BAF41DA5ABD1FFEDC6D2FEA56B";

String createNonce() {
  var uuid = const Uuid();
  String nonce = uuid.v1();
  return nonce.replaceAll("-", "");
}

String createSignature(String path, String nonce, String time, String method) {
  String key = path + time + nonce + method + apiKey;
  String data =
      r'~d}$Q7$eIni=V)9\RK/P.RM4;9[7|@/CA}b~OW!3?EV`:<>M7pddUBL5n|0/*Cn';
  var s = utf8.encode(key.toLowerCase());
  var f = utf8.encode(data);
  var hmacSha256 = Hmac(sha256, f);
  var digest = hmacSha256.convert(s);
  return digest.toString();
}

Map<String, String> getHeaders(String method, String token, String url) {
  var nonce = createNonce();
  var time = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
  var signature = createSignature(url, nonce, time, method);
  var headers = {
    "api-key": "C69BAF41DA5ABD1FFEDC6D2FEA56B",
    "accept": "application/vnd.picacomic.com.v1+json",
    "app-channel": "3",
    "authorization": token,
    "time": (int.parse(getConstants("time")) ~/ 1000).toString(),
    "nonce": nonce,
    "app-version": "2.2.1.3.3.4",
    "app-uuid": "defaultUuid",
    "image-quality": "original",
    "app-platform": "android",
    "app-build-version": "45",
    "Content-Type": "application/json; charset=UTF-8",
    "user-agent": "okhttp/3.8.1",
    "version": "v1.4.1",
    "Host": "picaapi.picacomic.com",
    "signature": signature,
  };
  return headers;
}