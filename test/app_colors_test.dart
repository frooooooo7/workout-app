import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';

void main() {
  group('AppColors — paleta Ember', () {
    test('primary to pomarańcz ember', () {
      expect(AppColors.primary, const Color(0xFFFF5A1F));
    });
    test('primaryVariant to jaśniejszy pomarańcz', () {
      expect(AppColors.primaryVariant, const Color(0xFFFF8A50));
    });
    test('onPrimary to ciemny (kontrast na pomarańczu)', () {
      expect(AppColors.onPrimary, const Color(0xFF1A0F08));
    });
    test('background to ciepła czerń', () {
      expect(AppColors.background, const Color(0xFF131110));
    });
    test('surface i surfaceVariant są ciepłe', () {
      expect(AppColors.surface, const Color(0xFF1B1713));
      expect(AppColors.surfaceVariant, const Color(0xFF241E19));
    });
    test('teksty i border w ciepłych odcieniach', () {
      expect(AppColors.textPrimary, const Color(0xFFFFF7F2));
      expect(AppColors.textSecondary, const Color(0xFFA89A8E));
      expect(AppColors.textMuted, const Color(0xFF6B5F56));
      expect(AppColors.border, const Color(0xFF2E2721));
    });
    test('gradienty bez fioletu', () {
      expect(AppColors.gradientTop, const Color(0xFF131110));
      expect(AppColors.gradientHero, const Color(0xFF2A1408));
    });
  });
}
