import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/ui/theme.dart';
import 'package:lianji/ui/liquid_glass.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android GPU真实折射且中心保持清透', (tester) async {
    expect(
      ui.ImageFilter.isShaderFilterSupported,
      isTrue,
      reason:
          'This acceptance requires an Impeller device, not a flat fallback.',
    );
    await LiquidGlassSurface.prepare();
    expect(
      LiquidGlassSurface.refractionReady,
      isTrue,
      reason: 'The real shader must load before claiming liquid refraction.',
    );
    final folder = Directory(
      '${(await getTemporaryDirectory()).path}/liquid-qa',
    );
    await folder.create(recursive: true);
    final dpr = tester.view.devicePixelRatio;
    final samples = <ui.Image>[];
    for (final enabled in [false, true]) {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: AppTheme.build(BrandTheme.blue, Brightness.light),
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const CustomPaint(painter: _OpticsPattern()),
                  Positioned(
                    left: 24,
                    top: 240,
                    width: 300,
                    height: 70,
                    child: LiquidGlassSurface(
                      refractionEnabled: enabled,
                      child: const ColoredBox(color: Color(0x01000000)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: dpr);
        samples.add(image);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${folder.path}/native-liquid-${enabled ? 'on' : 'off'}.png',
        ).writeAsBytes(png!.buffer.asUint8List());
      });
    }
    final before = (await samples[0].toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final after = (await samples[1].toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    double difference(Rect rect) {
      var total = 0.0, count = 0;
      for (
        var y = (rect.top * dpr).round();
        y < (rect.bottom * dpr).round();
        y++
      ) {
        for (
          var x = (rect.left * dpr).round();
          x < (rect.right * dpr).round();
          x++
        ) {
          final offset = (y * samples[0].width + x) * 4;
          for (var channel = 0; channel < 3; channel++) {
            total +=
                (before.getUint8(offset + channel) -
                        after.getUint8(offset + channel))
                    .abs();
            count++;
          }
        }
      }
      return total / count;
    }

    final edge = difference(const Rect.fromLTWH(100, 244, 140, 8));
    final center = difference(const Rect.fromLTWH(100, 267, 140, 16));
    debugPrint(
      'LIQUID_GPU supported=true ready=true edgeDifference=$edge centerDifference=$center',
    );
    expect(
      edge,
      greaterThan(5),
      reason: 'The real bevel must move the striped backdrop.',
    );
    expect(
      center,
      lessThan(edge),
      reason: 'The middle must stay clearer than the refractive edge.',
    );
    for (final image in samples) {
      image.dispose();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

// Synthetic optical measurement chart; never a production asset or record.
class _OpticsPattern extends CustomPainter {
  const _OpticsPattern();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var y = 0.0; y < size.height; y += 4) {
      paint.color = (y / 4).round().isEven
          ? const Color(0xff355e6b)
          : const Color(0xfff6fcff);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 4), paint);
    }
    paint.color = const Color(0xff62c9d6);
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OpticsPattern oldDelegate) => false;
}
