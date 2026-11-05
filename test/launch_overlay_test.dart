import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/launch/app_launch_controller.dart';
import 'package:gym/core/launch/launch_overlay.dart';
import 'package:gym/core/launch/launch_ready_signal.dart';
import 'package:gym/features/auth/presentation/screens/login_screen.dart';
import 'package:gym/features/training/presentation/widgets/training_staggered_entrance.dart';

/// Obrazki z `precacheImage` dekodują się poza zegarem testu.
Future<void> _decodeAssets(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump();
}

Widget _app(AppLaunchController launch, Widget home) {
  return MaterialApp(
    builder: (context, child) =>
        LaunchHost(controller: launch, child: child ?? const SizedBox()),
    home: home,
  );
}

Finder get _overlay => find.byType(LaunchOverlay);

void main() {
  testWidgets('nakładka startuje po zdekodowaniu logo i znika po gotowości', (
    tester,
  ) async {
    final launch = AppLaunchController();
    addTearDown(launch.dispose);

    await tester.pumpWidget(
      _app(
        launch,
        const LaunchReadySignal(
          target: LaunchTarget.training,
          ready: true,
          child: Scaffold(body: Text('Trening')),
        ),
      ),
    );
    await _decodeAssets(tester);

    // Nakładka zasłania ekran i nie przepuszcza dotyku.
    expect(find.text('Trening'), findsOneWidget);
    expect(find.text('STRONGER'), findsOneWidget);
    expect(launch.phase, LaunchPhase.intro);

    // Minimum 0,85 s, potem wyjście i koniec.
    await tester.pump(const Duration(milliseconds: 860));
    expect(launch.phase, LaunchPhase.exiting);
    await tester.pump(const Duration(milliseconds: 710));
    expect(launch.phase, LaunchPhase.done);
    expect(find.text('STRONGER'), findsNothing);
    expect(find.text('Trening'), findsOneWidget);
  });

  testWidgets('zniknięcie nakładki nie przebudowuje aplikacji pod nią', (
    tester,
  ) async {
    final launch = AppLaunchController();
    addTearDown(launch.dispose);
    final key = GlobalKey<_CounterState>();

    await tester.pumpWidget(
      _app(
        launch,
        LaunchReadySignal(
          target: LaunchTarget.training,
          ready: true,
          child: _Counter(key: key),
        ),
      ),
    );
    await _decodeAssets(tester);
    final state = key.currentState!;
    state.bump();
    await tester.pump(const Duration(milliseconds: 1700));

    expect(launch.phase, LaunchPhase.done);
    expect(key.currentState, same(state));
    expect(key.currentState!.count, 1);
  });

  testWidgets('bez gotowości ekran czeka, a limit 2,5 s i tak go odsłania', (
    tester,
  ) async {
    final launch = AppLaunchController();
    addTearDown(launch.dispose);

    await tester.pumpWidget(
      _app(
        launch,
        const LaunchReadySignal(
          target: LaunchTarget.training,
          ready: false,
          child: Scaffold(body: Text('Trening')),
        ),
      ),
    );
    await _decodeAssets(tester);

    await tester.pump(const Duration(milliseconds: 2400));
    expect(launch.phase, LaunchPhase.intro);
    // Po 1,2 s jest pasek ładowania, po 3 s opis (tu jeszcze go nie ma).
    expect(find.text('Przygotowuję Twoje dane…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(launch.phase, LaunchPhase.exiting);
    await tester.pump(const Duration(seconds: 1));
    expect(launch.phase, LaunchPhase.done);
  });

  testWidgets('wejście kart Treningu czeka na wyjście nakładki', (
    tester,
  ) async {
    final launch = AppLaunchController();
    addTearDown(launch.dispose);

    await tester.pumpWidget(
      _app(
        launch,
        const LaunchReadySignal(
          target: LaunchTarget.training,
          ready: true,
          child: Scaffold(
            body: TrainingStaggeredEntrance(index: 0, child: Text('Karta')),
          ),
        ),
      ),
    );
    await _decodeAssets(tester);

    double cardOpacity() => tester
        .widget<Opacity>(
          find
              .ancestor(of: find.text('Karta'), matching: find.byType(Opacity))
              .first,
        )
        .opacity;

    await tester.pump(const Duration(milliseconds: 500));
    expect(cardOpacity(), 0);

    await tester.pump(const Duration(milliseconds: 400));
    expect(launch.revealed, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(cardOpacity(), 1);
    // Dokończ wyjście nakładki (zegar końca).
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('logowanie: logo leci do karty, obrazki są już wczytane', (
    tester,
  ) async {
    final launch = AppLaunchController();
    addTearDown(launch.dispose);

    await tester.pumpWidget(_app(launch, const LoginScreen()));
    await _decodeAssets(tester);

    await tester.pump(const Duration(milliseconds: 900));
    expect(launch.phase, LaunchPhase.exiting);
    final target = launch.loginLogoTarget;
    expect(target, isNotNull);
    expect(target!.width, 48);

    await tester.pump(const Duration(milliseconds: 800));
    expect(launch.phase, LaunchPhase.done);
    // Karta logowania zdążyła wejść.
    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(_overlay, findsOneWidget);
  });

  testWidgets('wyłączone animacje: sam granat z logo, bez napisu', (
    tester,
  ) async {
    final launch = AppLaunchController();
    addTearDown(launch.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(
          launch,
          const LaunchReadySignal(
            target: LaunchTarget.training,
            ready: true,
            child: Scaffold(body: Text('Trening')),
          ),
        ),
      ),
    );
    await _decodeAssets(tester);

    expect(find.text('STRONGER'), findsNothing);
    expect(launch.reduceMotion, isTrue);
    // Bez minimum: wyjście zaraz po klatce z gotowością.
    await tester.pump();
    expect(launch.phase, LaunchPhase.exiting);
    await tester.pump(const Duration(seconds: 1));
    expect(launch.phase, LaunchPhase.done);
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  void bump() => setState(() => count++);

  @override
  Widget build(BuildContext context) => Text('$count');
}
