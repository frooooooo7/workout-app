import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/launch/app_launch_controller.dart';

void main() {
  const ms = Duration(milliseconds: 1);

  test('wychodzi dopiero po minimum, nawet gdy ekran jest gotowy od razu', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.start();
      c.attach(LaunchTarget.training);
      c.markReady(LaunchTarget.training);
      async.elapse(const Duration(milliseconds: 849));
      expect(c.phase, LaunchPhase.intro);
      async.elapse(ms);
      expect(c.phase, LaunchPhase.exiting);
      expect(c.revealed, isTrue);
      async.elapse(c.exitDuration);
      expect(c.phase, LaunchPhase.done);
      c.dispose();
    });
  });

  test('po minimum czeka na gotowość i wychodzi od razu, gdy ta przyjdzie', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.start();
      c.attach(LaunchTarget.training);
      async.elapse(const Duration(milliseconds: 1500));
      expect(c.phase, LaunchPhase.intro);
      c.markReady(LaunchTarget.training);
      expect(c.phase, LaunchPhase.exiting);
      c.dispose();
    });
  });

  test('czekanie na dane ma limit liczony od zbudowania ekranu', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.start();
      async.elapse(const Duration(seconds: 1));
      c.attach(LaunchTarget.training);
      async.elapse(const Duration(milliseconds: 2499));
      expect(c.phase, LaunchPhase.intro);
      async.elapse(ms);
      expect(c.phase, LaunchPhase.exiting);
      c.dispose();
    });
  });

  test('bezpiecznik kończy start, gdy żaden ekran się nie zgłosi', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.start();
      async.elapse(const Duration(seconds: 19));
      expect(c.phase, LaunchPhase.intro);
      async.elapse(const Duration(seconds: 1));
      expect(c.phase, LaunchPhase.exiting);
      c.dispose();
    });
  });

  test('logowanie czeka na zdjęcie i logo, a z nimi wychodzi od razu', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.start();
      c.attach(LaunchTarget.login);
      c.markReady(LaunchTarget.login);
      async.elapse(const Duration(seconds: 1));
      expect(c.phase, LaunchPhase.intro);
      c.markAssetsReady();
      expect(c.phase, LaunchPhase.exiting);
      c.dispose();
    });
  });

  test('przy locie logo cel jest odczytywany na początku wyjścia', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.loginLogoRect = () => const Rect.fromLTWH(182, 120, 48, 48);
      c.start();
      c.markAssetsReady();
      c.markReady(LaunchTarget.login);
      async.elapse(const Duration(seconds: 1));
      expect(c.loginLogoTarget, const Rect.fromLTWH(182, 120, 48, 48));
      c.dispose();
    });
  });

  test('zdjęcie nie blokuje Treningu', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.start();
      c.markReady(LaunchTarget.training);
      async.elapse(const Duration(milliseconds: 850));
      expect(c.phase, LaunchPhase.exiting);
      c.dispose();
    });
  });

  test('wyłączone animacje: bez minimum, wyjście zaraz po gotowości', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.start(reduceMotion: true);
      expect(c.phase, LaunchPhase.intro);
      c.markReady(LaunchTarget.training);
      expect(c.phase, LaunchPhase.exiting);
      c.dispose();
    });
  });

  test('gotowość przed startem zegarów nie kończy ekranu', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.markReady(LaunchTarget.training);
      async.elapse(const Duration(seconds: 2));
      expect(c.phase, LaunchPhase.intro);
      c.start();
      async.elapse(const Duration(milliseconds: 850));
      expect(c.phase, LaunchPhase.exiting);
      c.dispose();
    });
  });

  test('pasek po 1,2 s, opis po 3 s, opis „Łączę z serwerem” na życzenie', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      c.start();
      async.elapse(const Duration(milliseconds: 1199));
      expect(c.showProgress, isFalse);
      async.elapse(ms);
      expect(c.showProgress, isTrue);
      expect(c.showStatus, isFalse);
      async.elapse(const Duration(milliseconds: 1800));
      expect(c.showStatus, isTrue);
      expect(c.awaitingServer, isFalse);
      c.setAwaitingServer(true);
      expect(c.awaitingServer, isTrue);
      c.dispose();
    });
  });

  test('whenRevealed kończy się na początku wyjścia, whenDone po nim', () {
    fakeAsync((async) {
      final c = AppLaunchController();
      var revealed = false;
      var done = false;
      c.whenRevealed.then((_) => revealed = true);
      c.whenDone.then((_) => done = true);
      c.start();
      c.markReady(LaunchTarget.training);
      async.elapse(const Duration(milliseconds: 850));
      async.flushMicrotasks();
      expect(revealed, isTrue);
      expect(done, isFalse);
      async.elapse(c.exitDuration);
      async.flushMicrotasks();
      expect(done, isTrue);
      c.dispose();
    });
  });
}
