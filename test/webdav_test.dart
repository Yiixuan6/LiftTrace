import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lianji/data/webdav.dart';
import 'package:lianji/domain/models.dart';

void main() {
  test('WebDAV PUT/GET/MOVE/GET 完成后才成功；文件名独立', () async {
    final files = <String, String>{}, methods = <String>[];
    final client = WebDavClient(
      DavConfig('https://example.test/backups/', 'u', 'p'),
      client: MockClient((r) async {
        methods.add(r.method);
        if (r.method == 'PUT') {
          files[r.url.path] = r.body;
          return http.Response('', 201);
        }
        if (r.method == 'GET') {
          return http.Response(
            files[r.url.path]!,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (r.method == 'MOVE') {
          files[Uri.parse(r.headers['Destination']!).path] = files.remove(
            r.url.path,
          )!;
          return http.Response('', 201);
        }
        return http.Response('', 500);
      }),
    );
    final first = await client.upload(initialData()),
        second = await client.upload(initialData());
    expect(first, isNot(second));
    expect(methods, ['PUT', 'GET', 'MOVE', 'GET', 'PUT', 'GET', 'MOVE', 'GET']);
    expect(files.length, 2);
    client.close();
  });
  test('回读损坏不执行 MOVE，不宣称成功', () async {
    final methods = <String>[];
    final client = WebDavClient(
      DavConfig('https://example.test/b/', 'u', 'p'),
      client: MockClient((r) async {
        methods.add(r.method);
        return http.Response(
          r.method == 'GET' ? 'corrupt' : '',
          r.method == 'GET' ? 200 : 201,
        );
      }),
    );
    await expectLater(client.upload(initialData()), throwsFormatException);
    expect(methods, ['PUT', 'GET']);
    client.close();
  });
  test('认证失败与跨域路径拒绝；目录列表不暴露 partial 或其他路径', () async {
    final c = WebDavClient(
      DavConfig('https://example.test/b/', 'u', 'p'),
      client: MockClient((r) async => http.Response('', 401)),
    );
    await expectLater(c.test(), throwsFormatException);
    await expectLater(
      c.request('GET', Uri.parse('https://evil.test/b/a')),
      throwsFormatException,
    );
    c.close();
    expect(
      () => DavConfig('http://example.test', 'u', 'p'),
      throwsFormatException,
    );
    final xml =
        '<d:multistatus xmlns:d="DAV:">${['/b/lianji-a.json', '/b/lianji-b.json.partial', '/private/lianji-c.json', 'https://evil.test/b/lianji-d.json'].map((href) => '<d:response><d:href>$href</d:href><d:propstat><d:prop><d:getcontentlength>10</d:getcontentlength></d:prop></d:propstat></d:response>').join()}</d:multistatus>';
    final listClient = WebDavClient(
      DavConfig('https://example.test/b/', 'u', 'p'),
      client: MockClient(
        (r) async => http.Response.bytes(utf8.encode(xml), 207),
      ),
    );
    expect((await listClient.list()).map((b) => b.name), ['lianji-a.json']);
    listClient.close();
  });
}
