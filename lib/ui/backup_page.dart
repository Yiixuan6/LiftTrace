import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../application/controller.dart';
import '../data/backup.dart';
import '../data/webdav.dart';
import '../platform/background_backup.dart';
import '../platform/export_filename.dart';
import 'active_workout.dart';
import 'components.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupState();
}

class _BackupState extends ConsumerState<BackupPage> {
  final url = TextEditingController(),
      user = TextEditingController(),
      password = TextEditingController();
  final credentials = DavCredentialStore();
  bool busy = false, configured = false;
  String? error, message;
  List<RemoteBackup> backups = [];
  Map<String, bool> valid = {};
  String? lastSuccess;
  @override
  void initState() {
    super.initState();
    loadConfig();
  }

  Future<void> loadConfig() async {
    try {
      final config = await credentials.read(),
          status = await credentials.readStatus();
      if (!mounted) return;
      setState(() {
        if (config != null) {
          url.text = config.url;
          user.text = config.username;
          password.text = config.password;
          configured = true;
        }
        lastSuccess = status['successAt'] as String?;
        if (status['error'] != null) error = status['error'] as String;
      });
    } catch (_) {
      if (mounted) setState(() => error = '无法读取安全凭据，请重新配置');
    }
  }

  @override
  void dispose() {
    url.dispose();
    user.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> work(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : '操作失败，请检查网络、权限或文件后重试。本地训练数据保留。',
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> withClient(Future<void> Function(WebDavClient) action) async {
    final config = await credentials.read();
    if (config == null) throw const FormatException('请先保存 WebDAV 配置');
    final client = WebDavClient(config);
    try {
      await action(client);
    } finally {
      client.close();
    }
  }

  Future<void> restore(String raw) async {
    final data = BackupCodec.decode(raw);
    final yes = await confirm(
      context,
      '替换本地数据？',
      '备份包含 ${data.sessions.where((s) => !s.deleted).length} 次训练、${data.templates.where((t) => !t.deleted).length} 个模板、${data.measurements.where((m) => !m.deleted).length} 条身体记录。\n\n完整恢复会替换本地业务数据及外观偏好，先自动保存恢复前备份。自动备份将关闭，设备提醒不迁移。',
    );
    if (!yes) return;
    final dir = await getApplicationSupportDirectory();
    await ref.read(remindersProvider).cancel();
    await BackgroundBackup.cancel();
    await ref
        .read(controllerProvider)
        .restore(raw, Directory('${dir.path}/before-restore'));
    if (mounted) setState(() => message = '恢复完成。恢复前备份保留在应用私有目录，可用下方入口导出。');
  }

  Future<void> exportFile(String content, String extension) async {
    final name = await exportFilename(extension);
    final result = await FilePicker.saveFile(
      mimeType: extension == 'json' ? 'application/json' : 'text/csv',
      dialogTitle: '导出文件',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    if (result != null && mounted) setState(() => message = '文件已导出');
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    return PageBody(
      title: '备份与恢复',
      subtitle: '完整 JSON 用于恢复，CSV 用于分析。数据只在你导出或启用 WebDAV 后传出。',
      children: [
        if (busy) const LinearProgressIndicator(semanticsLabel: '正在处理备份操作'),
        if (error != null) ErrorState(message: error!),
        if (message != null) Text(message!),
        Text('本地文件', style: Theme.of(context).textTheme.titleLarge),
        EqualActionGroup(
          key: const ValueKey('local-file-actions'),
          labels: const ['导出完整 JSON', '导出分析 CSV', '从 JSON 完整恢复', '导出最近恢复前备份'],
          children: [
            FilledButton.tonal(
              onPressed: busy
                  ? null
                  : () => work(
                      () => exportFile(BackupCodec.encode(c.data), 'json'),
                    ),
              child: const Text('导出完整 JSON'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () =>
                        work(() => exportFile(BackupCodec.csv(c.data), 'csv')),
              child: const Text('导出分析 CSV'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => work(() async {
                      final file = await FilePicker.pickFile(
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                      );
                      if (file == null) return;
                      if ((await file.length() ?? 0) > BackupCodec.maxBytes) {
                        throw const FormatException('文件超过 50 MB 限制');
                      }
                      final bytes = <int>[];
                      await for (final chunk in file.readAsByteStream()) {
                        if (bytes.length + chunk.length >
                            BackupCodec.maxBytes) {
                          throw const FormatException('文件超过 50 MB 限制');
                        }
                        bytes.addAll(chunk);
                      }
                      await restore(utf8.decode(bytes));
                    }),
              child: const Text('从 JSON 完整恢复'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => work(() async {
                      final dir = Directory(
                        '${(await getApplicationSupportDirectory()).path}/before-restore',
                      );
                      if (!await dir.exists()) {
                        throw const FormatException('还没有恢复前备份');
                      }
                      final files = await dir
                          .list()
                          .where((f) => f is File && f.path.endsWith('.json'))
                          .cast<File>()
                          .toList();
                      files.sort((a, b) => b.path.compareTo(a.path));
                      if (files.isEmpty) {
                        throw const FormatException('还没有恢复前备份');
                      }
                      await exportFile(
                        await files.first.readAsString(),
                        'json',
                      );
                    }),
              child: const Text('导出最近恢复前备份'),
            ),
          ],
        ),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('旧网站追加导入：待取得网站源码和真实 JSON 后实现。当前仅支持练迹完整备份格式。'),
          ),
        ),
        Text('WebDAV', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          '单手机备份与换机恢复。请填写已存在、允许 PROPFIND / PUT / GET / MOVE 的 HTTPS 目录。凭据保存在设备安全存储，不进入备份。',
        ),
        LabeledTextField(
          controller: url,
          enabled: !busy,
          keyboardType: TextInputType.url,
          label: 'HTTPS 备份目录',
        ),
        LabeledTextField(
          controller: user,
          enabled: !busy,
          autocorrect: false,
          label: '用户名',
        ),
        LabeledTextField(
          controller: password,
          enabled: !busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          label: '密码或专用密码',
        ),
        EqualActionGroup(
          key: const ValueKey('webdav-actions'),
          labels: const ['保存配置', '测试连接', '立即备份', '移除配置'],
          children: [
            FilledButton.tonal(
              onPressed: busy
                  ? null
                  : () => work(() async {
                      await credentials.save(
                        DavConfig(url.text.trim(), user.text, password.text),
                      );
                      setState(() {
                        configured = true;
                        message = '配置已保存在设备安全存储';
                      });
                    }),
              child: const Text('保存配置'),
            ),
            OutlinedButton(
              onPressed: busy || !configured
                  ? null
                  : () => work(
                      () => withClient((client) async {
                        await client.test();
                        setState(() => message = '连接成功，目录可读取；写入权限将在备份时验证');
                      }),
                    ),
              child: const Text('测试连接'),
            ),
            OutlinedButton(
              onPressed: busy || !configured
                  ? null
                  : () => work(
                      () => withClient((client) async {
                        final revision = c.data.revision;
                        await client.upload(c.data.copy());
                        final now = DateTime.now().toUtc().toIso8601String();
                        await credentials.status({
                          'revision': revision,
                          'successAt': now,
                        });
                        setState(() {
                          lastSuccess = now;
                          message = '上传成功，最终文件回读校验通过';
                        });
                      }),
                    ),
              child: const Text('立即备份'),
            ),
            OutlinedButton(
              onPressed: busy || !configured
                  ? null
                  : () => work(() async {
                      await c.change((d) => d.settings['autoBackup'] = false);
                      await BackgroundBackup.cancel();
                      await credentials.clear();
                      password.clear();
                      setState(() {
                        configured = false;
                        backups = [];
                        valid = {};
                        message = '已移除本机凭据，远端历史保留';
                      });
                    }),
              child: const Text('移除配置'),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自动备份'),
          subtitle: const Text('默认关闭。联网后合并数据变化，后台重试，不承诺实时执行。无变化时跳过。'),
          value: c.data.settings['autoBackup'] == true,
          onChanged: busy || !configured
              ? null
              : (v) => work(() async {
                  await c.change((d) => d.settings['autoBackup'] = v);
                  if (v) {
                    await BackgroundBackup.schedule();
                  } else {
                    await BackgroundBackup.cancel();
                  }
                }),
        ),
        Text('上次成功：${lastSuccess ?? '暂无'}'),
        OutlinedButton.icon(
          onPressed: busy || !configured
              ? null
              : () => work(
                  () => withClient((client) async {
                    final list = await client.list();
                    if (mounted) {
                      setState(() {
                        backups = list;
                        valid = {};
                      });
                    }
                  }),
                ),
          icon: const Icon(Icons.refresh),
          label: const Text('列出远端备份'),
        ),
        const Text('远端历史不会自动删除。未校验文件须先下载验证，损坏文件不会开放恢复。'),
        ...backups.map(
          (b) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(b.name),
                  Text(
                    '${b.bytes ?? '未知'} bytes · ${valid[b.name] == true
                        ? '校验可用'
                        : valid[b.name] == false
                        ? '损坏或不可读取'
                        : '待校验'}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => work(
                                () => withClient((client) async {
                                  try {
                                    await client.download(b);
                                    setState(() => valid[b.name] = true);
                                  } catch (_) {
                                    setState(() => valid[b.name] = false);
                                    rethrow;
                                  }
                                }),
                              ),
                        child: const Text('验证文件'),
                      ),
                      FilledButton.tonal(
                        onPressed: busy || valid[b.name] != true
                            ? null
                            : () => work(
                                () => withClient((client) async {
                                  await restore(await client.download(b));
                                }),
                              ),
                        child: const Text('恢复此备份'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
