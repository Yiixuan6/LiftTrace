import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../domain/models.dart';
import 'backup.dart';

class DavConfig {
  DavConfig(this.url, this.username, this.password) {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('请使用不含凭据、查询参数的 HTTPS 目录地址');
    }
  }
  final String url, username, password;
  Uri get directory => Uri.parse(url.endsWith('/') ? url : '$url/');
}

class DavCredentialStore {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  Future<void> save(DavConfig config) => storage.write(
    key: 'webdav',
    value: jsonEncode({
      'url': config.url,
      'username': config.username,
      'password': config.password,
    }),
  );
  Future<DavConfig?> read() async {
    final raw = await storage.read(key: 'webdav');
    if (raw == null) return null;
    final j = jsonDecode(raw) as Json;
    return DavConfig(
      j['url'] as String,
      j['username'] as String,
      j['password'] as String,
    );
  }

  Future<void> clear() => storage.delete(key: 'webdav');
  Future<void> status(Json value) =>
      storage.write(key: 'davStatus', value: jsonEncode(value));
  Future<Json> readStatus() async =>
      jsonDecode(await storage.read(key: 'davStatus') ?? '{}') as Json;
}

class RemoteBackup {
  RemoteBackup(this.uri, this.name, this.bytes, this.modified);
  final Uri uri;
  final String name;
  final int? bytes;
  final DateTime? modified;
}

class WebDavClient {
  WebDavClient(this.config, {http.Client? client})
    : client = client ?? http.Client();
  final DavConfig config;
  final http.Client client;
  void close() => client.close();
  Future<http.Response> request(
    String method,
    Uri uri, {
    String? body,
    Map<String, String>? headers,
  }) async {
    // Never forward authorization across redirects or outside configured folder.
    if (uri.origin != config.directory.origin ||
        !uri.path.startsWith(config.directory.path)) {
      throw const FormatException('远端路径超出备份目录');
    }
    final req = http.Request(method, uri)..followRedirects = false;
    req.headers.addAll({
      'Authorization':
          'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
      ...?headers,
    });
    if (body != null) req.bodyBytes = utf8.encode(body);
    final stream = await client.send(req).timeout(const Duration(seconds: 45));
    if ((stream.contentLength ?? 0) > BackupCodec.maxBytes) {
      throw const FormatException('远端文件过大');
    }
    final bytes = <int>[];
    await for (final chunk in stream.stream.timeout(
      const Duration(seconds: 45),
    )) {
      if (bytes.length + chunk.length > BackupCodec.maxBytes) {
        throw const FormatException('远端文件过大');
      }
      bytes.addAll(chunk);
    }
    final response = http.Response.bytes(
      bytes,
      stream.statusCode,
      headers: stream.headers,
      request: req,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(switch (response.statusCode) {
        401 || 403 => '认证失败或目录无写入权限',
        404 => '备份目录不存在，请先在服务端建立目录',
        507 => '远端空间不足',
        _ => 'WebDAV 请求失败（${response.statusCode}）',
      });
    }
    if (response.bodyBytes.length > BackupCodec.maxBytes) {
      throw const FormatException('远端文件过大');
    }
    return response;
  }

  Future<void> test() async {
    await request('PROPFIND', config.directory, headers: {'Depth': '0'});
  }

  Future<String> upload(AppData data) async {
    final content = BackupCodec.encode(data);
    final name =
        'lianji-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}-${newId()}.json';
    final temp = config.directory.resolve('$name.partial'),
        target = config.directory.resolve(name);
    await request(
      'PUT',
      temp,
      body: content,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'If-None-Match': '*',
      },
    );
    final read = await request('GET', temp);
    BackupCodec.decode(utf8.decode(read.bodyBytes));
    if (utf8.decode(read.bodyBytes) != content) {
      throw const FormatException('上传回读不一致');
    }
    await request(
      'MOVE',
      temp,
      headers: {'Destination': target.toString(), 'Overwrite': 'F'},
    );
    final finalRead = await request('GET', target);
    if (utf8.decode(finalRead.bodyBytes) != content) {
      throw const FormatException('最终文件回读不一致');
    }
    BackupCodec.decode(utf8.decode(finalRead.bodyBytes));
    return name;
  }

  Future<List<RemoteBackup>> list() async {
    final res = await request(
      'PROPFIND',
      config.directory,
      headers: {'Depth': '1', 'Content-Type': 'application/xml'},
      body:
          '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:getcontentlength/><d:getlastmodified/></d:prop></d:propfind>',
    );
    final doc = XmlDocument.parse(utf8.decode(res.bodyBytes));
    final results = <RemoteBackup>[];
    for (final entry in doc.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'response',
    )) {
      String? value(String local) => entry.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == local)
          .firstOrNull
          ?.innerText;
      final href = value('href');
      if (href == null) continue;
      final uri = config.directory.resolve(href);
      if (uri.origin != config.directory.origin ||
          !uri.path.startsWith(config.directory.path)) {
        continue;
      }
      final relative = uri.path.substring(config.directory.path.length);
      if (relative.contains('/') ||
          !relative.startsWith('lianji-') ||
          !relative.endsWith('.json')) {
        continue;
      }
      DateTime? modified;
      try {
        modified = HttpDate.parse(value('getlastmodified') ?? '');
      } catch (_) {
        /* Invalid server date is displayed as unavailable. */
      }
      results.add(
        RemoteBackup(
          uri,
          relative,
          int.tryParse(value('getcontentlength') ?? ''),
          modified,
        ),
      );
    }
    results.sort((a, b) => b.name.compareTo(a.name));
    return results;
  }

  Future<String> download(RemoteBackup backup) async {
    final r = await request('GET', backup.uri);
    final raw = utf8.decode(r.bodyBytes);
    BackupCodec.decode(raw);
    return raw;
  }
}
