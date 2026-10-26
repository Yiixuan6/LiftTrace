import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A single backdrop pass. Foreground icons are never refracted.
class LiquidGlassSurface extends StatefulWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.refractionEnabled = true,
  });
  final Widget child;
  final bool refractionEnabled;
  static ui.FragmentProgram? _program;
  static Future<void>? _preparing;
  static Future<void> prepare() => _preparing ??= _load();
  static Future<void> _load() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/liquid_glass.frag',
      );
    } catch (_) {
      // Old backends or an unavailable program retain a usable clear surface.
      // Device acceptance must distinguish this from actual refraction.
    }
  }

  static bool get refractionReady => _program != null;
  @override
  State<LiquidGlassSurface> createState() => _LiquidGlassSurfaceState();
}

class _LiquidGlassSurfaceState extends State<LiquidGlassSurface> {
  @override
  void initState() {
    super.initState();
    if (!LiquidGlassSurface.refractionReady) {
      LiquidGlassSurface.prepare().then((_) {
        if (mounted && LiquidGlassSurface.refractionReady) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _LiquidOpticsPainter(dark: dark, shadow: true),
      foregroundPainter: _LiquidOpticsPainter(dark: dark),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(48),
        child: _LiquidBackdrop(
          program: widget.refractionEnabled
              ? LiquidGlassSurface._program
              : null,
          dpr: MediaQuery.devicePixelRatioOf(context),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Selected lens uses surface highlights, not a second backdrop filter. This
/// avoids sampling another glass layer's previous frame on mobile GPUs.
class LiquidSelectionLens extends StatelessWidget {
  const LiquidSelectionLens({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _LiquidOpticsPainter(
      dark: Theme.of(context).brightness == Brightness.dark,
      selection: true,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .30),
            Theme.of(context).colorScheme.primary.withValues(alpha: .065),
            Colors.white.withValues(alpha: .08),
          ],
        ),
      ),
      child: child,
    ),
  );
}

class _LiquidBackdrop extends SingleChildRenderObjectWidget {
  const _LiquidBackdrop({
    required this.program,
    required this.dpr,
    required super.child,
  });
  final ui.FragmentProgram? program;
  final double dpr;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLiquidBackdrop(program, dpr);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLiquidBackdrop renderObject,
  ) {
    renderObject.configure(program, dpr);
  }
}

class _RenderLiquidBackdrop extends RenderProxyBox {
  _RenderLiquidBackdrop(this._program, this._dpr) {
    _shader = _program?.fragmentShader();
  }
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  double _dpr;
  void configure(ui.FragmentProgram? program, double dpr) {
    if (program != _program) {
      _shader?.dispose();
      _program = program;
      _shader = program?.fragmentShader();
    }
    _dpr = dpr;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;
  @override
  void paint(PaintingContext context, Offset offset) {
    final shader = _shader;
    ui.ImageFilter filter;
    if (shader != null && ui.ImageFilter.isShaderFilterSupported) {
      final origin = localToGlobal(Offset.zero);
      shader.setFloat(2, _dpr);
      shader.setFloat(3, origin.dx);
      shader.setFloat(4, origin.dy);
      shader.setFloat(5, size.width);
      shader.setFloat(6, size.height);
      shader.setFloat(7, 9.0);
      filter = ui.ImageFilter.shader(shader);
    } else {
      // Skia/older Android: clear highlights with very slight diffusion.
      // No claim of physical refraction on an unsupported backend.
      filter = ui.ImageFilter.blur(
        sigmaX: .45,
        sigmaY: .45,
        tileMode: TileMode.clamp,
      );
    }
    final backdrop = (layer as BackdropFilterLayer?) ?? BackdropFilterLayer();
    backdrop.filter = filter;
    layer = backdrop;
    context.pushLayer(backdrop, super.paint, offset);
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }
}

class _LiquidOpticsPainter extends CustomPainter {
  const _LiquidOpticsPainter({
    required this.dark,
    this.shadow = false,
    this.selection = false,
  });
  final bool dark, shadow, selection;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      rect.deflate(.7),
      Radius.circular(size.height / 2),
    );
    if (shadow) {
      // Outside-only shadow: never put a gray shadow underneath the clear face.
      canvas.save();
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(30)),
          Path()..addRRect(shape),
        ),
      );
      canvas.drawRRect(
        shape.shift(const Offset(0, 5)),
        Paint()
          ..color = Colors.black.withValues(alpha: dark ? .24 : .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.restore();
      return;
    }
    final stroke = Paint()..style = PaintingStyle.stroke;
    // A restrained double bevel, with directional highlights and a thin dark
    // counter-edge, gives thickness even over the app's near-white background.
    stroke
      ..strokeWidth = selection ? 1.0 : 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .95),
          (selection ? const Color(0xff8ce8ee) : Colors.white).withValues(
            alpha: selection ? .16 : .58,
          ),
          Colors.white.withValues(alpha: .36),
          (selection ? const Color(0xff375461) : Colors.black).withValues(
            alpha: dark ? .38 : .28,
          ),
          (selection ? const Color(0xfff8d9ef) : Colors.white).withValues(
            alpha: .65,
          ),
          Colors.white.withValues(alpha: .9),
        ],
        stops: const [0, .18, .43, .64, .82, 1],
      ).createShader(rect);
    canvas.drawRRect(shape, stroke);
    stroke
      ..strokeWidth = selection ? 1.3 : 3.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: dark ? .32 : .62),
          Colors.white.withValues(alpha: .025),
          Colors.white.withValues(alpha: .20),
        ],
        stops: const [0, .48, 1],
      ).createShader(rect);
    canvas.drawRRect(shape.deflate(selection ? 1.6 : 2.5), stroke);
  }

  @override
  bool shouldRepaint(covariant _LiquidOpticsPainter old) =>
      old.dark != dark || old.shadow != shadow || old.selection != selection;
}
