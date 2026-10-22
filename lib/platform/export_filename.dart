import 'package:flutter/services.dart';

/// Uses the installed application's label and the device's local calendar date.
Future<String> exportFilename(String extension, {DateTime? now}) async {
  const channel = MethodChannel('app.lianji.training/app-info');
  final name = await channel.invokeMethod<String>('getApplicationName');
  if (name == null || name.trim().isEmpty) {
    throw const FormatException('无法读取应用名称，请重试导出');
  }
  final date = (now ?? DateTime.now()).toLocal();
  final day =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return '$name-$day.$extension';
}
