import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/auth/presentation/widgets/auth_hero_background.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_launch_controller.dart';
import 'app_launch_scope.dart';
import 'native_splash_gate.dart';

const _logoAsset = 'assets/images/logo.webp';
const _photoAsset = 'assets/images/login-hero.webp';

/// Obudowuje aplikację: udostępnia [AppLaunchController] i rysuje nad
/// routerem ekran ładowania (wariant B: logo na zdjęciu siłowni).
///
/// Drzewo jest zawsze takie samo (aplikacja + nakładka), więc zniknięcie
/// nakładki nie przebudowuje Navigatora.
class LaunchHost extends StatelessWidget {
  const LaunchHost({super.key, required this.controller, required this.child});

  final AppLaunchController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppLaunchScope(
      controller: controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned.fill(child: LaunchOverlay(controller: controller)),
        ],
      ),
    );
  }
}

/// Ekran ładowania: pierwsza klatka jest identyczna ze splashem systemowym
/// (granat i logo na środku), potem wjeżdża zdjęcie, logo unosi się, pojawia
/// się napis. Wychodzi, gdy kontroler da znać, że ekran pod spodem gotowy.
class LaunchOverlay extends StatefulWidget {
  const LaunchOverlay({super.key, required this.controller});

  final AppLaunchController controller;

  @override
  State<LaunchOverlay> createState() => _LaunchOverlayState();
}

class _LaunchOverlayState extends State<LaunchOverlay>
    with TickerProviderStateMixin {
  static const _logoWidth = 150.0;
  static const _logoRatio = 286 / 468;
  static const _lift = 40.0;
  static const _introMs = 1250.0;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: widget.controller.exitDuration,
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _prepared = false;
  bool _photoReady = false;
  LaunchPhase _lastPhase = LaunchPhase.intro;

  AppLaunchController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) return;
    _prepared = true;
    _prepare();
  }

  /// Dekoduje logo (potem startuje wejście i puszcza pierwszą klatkę),
  /// a w tle zdjęcie — bez niego logowanie nie wyjdzie z ekranu ładowania.
  Future<void> _prepare() async {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // Bezpieczniki startu nie mogą zależeć od logo: gdy się nie zdekoduje,
    // po limicie i tak ruszamy.
    await precacheImage(
      const AssetImage(_logoAsset),
      context,
      onError: (_, _) {},
    ).timeout(NativeSplashGate.limit, onTimeout: () {});
    if (!mounted) return;
    NativeSplashGate.release();
    _c.start(reduceMotion: reduceMotion);
    if (!reduceMotion) _intro.forward();

    await precacheImage(
      const AssetImage(_photoAsset),
      context,
      onError: (_, _) {},
    );
    if (!mounted) return;
    setState(() => _photoReady = true);
    _c.markAssetsReady();
  }

  void _onController() {
    if (!mounted) return;
    final phase = _c.phase;
    if (phase != _lastPhase) {
      _lastPhase = phase;
      if (phase == LaunchPhase.exiting) {
        _out.forward();
      } else if (phase == LaunchPhase.done) {
        _loop.stop();
        _intro.stop();
      }
    }
    if (_c.showProgress && !_loop.isAnimating && phase == LaunchPhase.intro) {
      _loop.repeat();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    _intro.dispose();
    _out.dispose();
    _loop.dispose();
    super.dispose();
  }

  double _seg(double ms0, double ms1, [Curve curve = Curves.linear]) {
    final t = ((_intro.value * _introMs - ms0) / (ms1 - ms0)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  double _outSeg(double ms0, double ms1, [Curve curve = Curves.linear]) {
    final total = _c.exitDuration.inMilliseconds.toDouble();
    final t = ((_out.value * total - ms0) / (ms1 - ms0)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    if (_c.phase == LaunchPhase.done) return const SizedBox.shrink();
    final intro = _c.phase == LaunchPhase.intro;
    final content = Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: AppFonts.ui,
          decoration: TextDecoration.none,
          color: AppColors.textPrimary,
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _out, _loop]),
          builder: (context, _) => _buildScene(context),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlockSemantics(
        blocking: intro,
        child: Semantics(
          container: true,
          label: 'Stronger, wczytywanie',
          child: intro
              ? AbsorbPointer(child: content)
              : IgnorePointer(child: content),
        ),
      ),
    );
  }

  Widget _buildScene(BuildContext context) {
    final reduceMotion = _c.reduceMotion;
    final exiting = _c.phase == LaunchPhase.exiting;
    final target = _c.loginLogoTarget;
    final toLogin =
        exiting && _c.target == LaunchTarget.login && target != null;

    return LayoutBuilder(
      builder: (context, box) {
        final cx = box.maxWidth / 2;
        final cy = box.maxHeight / 2;

        // Wejście.
        final liftT = reduceMotion ? 0.0 : _seg(0, 520, Curves.easeOutCubic);
        final glowT = _seg(100, 750, Curves.easeOutCubic);
        final photoT = _seg(100, 800, Curves.easeOut);
        final zoomT = _seg(0, 900, Curves.easeOutCubic);
        final wordT = _seg(250, 750, Curves.easeOutCubic);
        final tagT = _seg(400, 850, Curves.easeOutCubic);
        final shineT = _seg(500, 1250, Curves.easeInOut);
        final breathe = math.sin(_loop.value * math.pi);

        // Wyjście.
        double bgFade = 1;
        double fgFade = 1;
        double fgScale = 1;
        double logoOpacity = 1;
        double logoScale = 1;
        Offset logoShift = Offset.zero;
        if (exiting) {
          if (reduceMotion) {
            bgFade = fgFade = logoOpacity = 1 - _outSeg(0, 200);
          } else if (toLogin) {
            final morph = _outSeg(0, 620, Curves.easeInOutCubic);
            final landing = Offset(target.center.dx, target.center.dy);
            logoShift = (landing - Offset(cx, cy - _lift)) * morph;
            logoScale = 1 + (target.width / _logoWidth - 1) * morph;
            logoOpacity = 1 - _outSeg(496, 620);
            fgFade = 1 - _outSeg(0, 200, Curves.easeIn);
            bgFade = 1 - _outSeg(100, 480, Curves.easeIn);
          } else {
            final go = _outSeg(0, 320, Curves.easeInCubic);
            logoScale = 1 + .14 * go;
            logoOpacity = 1 - go;
            final fg = _outSeg(0, 220, Curves.easeIn);
            fgFade = 1 - fg;
            fgScale = 1 + .03 * fg;
            bgFade = 1 - _outSeg(80, 460, Curves.easeIn);
          }
        }

        final glowSize = 360.0;
        final slowGlow = _c.showProgress ? 1 + .1 * breathe : 1.0;
        final showStatus = _c.showStatus && !exiting;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Tło: granat, zdjęcie siłowni i poświata znikają razem.
            Opacity(
              opacity: bgFade,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.background),
                  if (!reduceMotion && _photoReady)
                    Opacity(
                      opacity: photoT,
                      child: Transform.scale(
                        scale: 1.06 - .06 * zoomT,
                        child: const AuthHeroBackground(
                          imageAsset: _photoAsset,
                          child: SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (!reduceMotion)
                    Positioned(
                      left: cx - glowSize / 2,
                      top: cy - _lift - glowSize / 2,
                      width: glowSize,
                      height: glowSize,
                      child: Opacity(
                        opacity: (glowT * (1 - .3 * breathe)).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: (.6 + .4 * glowT) * slowGlow,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color(0x427048F0),
                                  Color(0x1A5070F0),
                                  Color(0x002563EB),
                                ],
                                stops: [0, .55, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Napisy i stan ładowania.
            if (!reduceMotion)
              Opacity(
                opacity: fgFade,
                child: Transform.scale(
                  scale: fgScale,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: cy + 24 + 10 * (1 - wordT),
                        child: Opacity(
                          opacity: wordT,
                          child: _Word(progress: wordT),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: cy + 60 + 8 * (1 - tagT),
                        child: Opacity(opacity: tagT, child: const _Tagline()),
                      ),
                      Positioned(
                        left: cx - 60,
                        top: cy + 116,
                        width: 120,
                        child: AnimatedOpacity(
                          opacity: _c.showProgress ? 1 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: _ProgressBar(progress: _loop.value),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        top: cy + 136,
                        child: AnimatedOpacity(
                          opacity: showStatus ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _c.awaitingServer
                                ? 'Łączę z serwerem…'
                                : 'Przygotowuję Twoje dane…',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Logo: w pierwszej klatce dokładnie tam, gdzie logo splashu.
            Positioned(
              left: cx - _logoWidth / 2,
              top: cy - _logoWidth * _logoRatio / 2 - _lift * liftT,
              width: _logoWidth,
              height: _logoWidth * _logoRatio,
              child: Transform.translate(
                offset: logoShift,
                child: Transform.scale(
                  scale: logoScale,
                  child: Opacity(
                    opacity: logoOpacity.clamp(0.0, 1.0),
                    child: _ShineLogo(progress: reduceMotion ? 0 : shineT),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Logo, przez które raz przechodzi błysk ([progress] 0 → 1).
class _ShineLogo extends StatelessWidget {
  const _ShineLogo({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    const logo = Image(
      image: AssetImage(_logoAsset),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    if (progress <= 0 || progress >= 1) return logo;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) {
        final band = rect.width * .5;
        final center = rect.left - band + (rect.width + band * 2) * progress;
        return const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0xB3FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(center - band / 2, 0, band, rect.height));
      },
      child: logo,
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    // Rozstrzelone litery zbliżają się do docelowego odstępu.
    final spacing = 24 * (.42 + (.156 - .42) * progress);
    return Padding(
      padding: EdgeInsets.only(left: spacing),
      child: Text(
        'STRONGER',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: spacing,
        ),
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 3.6),
      child: Text(
        'TRAIN. TRACK. EVOLVE.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 3.6,
        ),
      ),
    );
  }
}

/// Cienki pasek ładowania (pokazuje się tylko przy wolnym starcie).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            return Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: AppColors.surfaceVariant),
                ),
                Positioned(
                  left: -w * .4 + w * 1.4 * progress,
                  top: 0,
                  bottom: 0,
                  width: w * .4,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Color(0xFF7B61FF)],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
