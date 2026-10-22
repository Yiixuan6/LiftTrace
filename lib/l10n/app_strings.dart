import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// UI messages only. Never pass user-authored names or notes to [text].
class AppStrings {
  AppStrings(this.locale, [this.messages = const {}]);
  final Locale locale;
  final Map<String, String> messages;
  static const simplified = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
  );
  static const traditional = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
  );
  static const english = Locale('en');
  static const supportedLocales = [simplified, traditional, english];
  static const preferences = ['system', 'zh_Hans', 'zh_Hant', 'en'];
  static const delegate = _StringsDelegate();

  static Locale resolve(Locale? device) {
    if (device?.languageCode == 'en') return english;
    if (device?.languageCode == 'zh' &&
        (device?.scriptCode == 'Hant' ||
            ['TW', 'HK', 'MO'].contains(device?.countryCode))) {
      return traditional;
    }
    return simplified;
  }

  static Locale? preferred(String? preference) => switch (preference) {
    'system' => null,
    'en' => english,
    'zh_Hant' => traditional,
    _ => simplified,
  };

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      AppStrings(simplified);

  static final _cache = <Locale, AppStrings>{
    simplified: AppStrings(simplified),
  };
  static Future<void> prepare() async {
    await Future.wait([load(english), load(traditional)]);
  }

  static Future<AppStrings> load(Locale locale) {
    final resolved = resolve(locale);
    final cached = _cache[resolved];
    if (cached != null) return SynchronousFuture(cached);
    return _loadAsset(resolved);
  }

  static Future<AppStrings> _loadAsset(Locale resolved) async {
    final code = resolved == traditional ? 'zh_Hant' : 'en';
    final raw = await rootBundle.loadString('assets/translations/$code.json');
    return _cache[resolved] = AppStrings(
      resolved,
      (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>(),
    );
  }

  String text(String key, [List<Object?> arguments = const []]) {
    final template = messages[key] ?? key;
    // A single pass avoids interpreting braces that came from user data.
    return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
      final index = int.parse(match[1]!);
      return index < arguments.length ? '${arguments[index] ?? ''}' : match[0]!;
    });
  }

  String error(String message) {
    final dav = RegExp(r'^WebDAV 请求失败（(\d+)）$').firstMatch(message);
    if (dav != null) return text('WebDAV 请求失败（{0}）', [dav[1]]);
    final migration = RegExp(r'^缺少数据库 (.+) → (.+) 的迁移$').firstMatch(message);
    if (migration != null) {
      return text('缺少数据库 {0} → {1} 的迁移', [migration[1], migration[2]]);
    }
    return text(message);
  }

  String weekday(int weekday, {bool short = false}) {
    final name = ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
    return text('${short ? '周' : '星期'}$name');
  }
}

class _StringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _StringsDelegate();
  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) => AppStrings.load(locale);
  @override
  bool shouldReload(_StringsDelegate old) => false;
}

String tr(
  BuildContext context,
  String key, [
  List<Object?> arguments = const [],
]) => AppStrings.of(context).text(key, arguments);

String trError(BuildContext context, String message) =>
    AppStrings.of(context).error(message);
