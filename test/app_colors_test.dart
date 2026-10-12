import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';

void main() {
  group('AppColors — paleta Steel Blue', () {
    test('primary to niebieski akcent', () {
      expect(AppColors.primary, const Color(0xFF2563EB));
    });
    test('primaryVariant to jaśniejszy niebieski', () {
      expect(AppColors.primaryVariant, const Color(0xFF5B8DF6));
    });
    test('onPrimary to biały (kontrast na niebieskim)', () {
      expect(AppColors.onPrimary, const Color(0xFFFFFFFF));
    });
    test('background to ciemny grafit-niebieski', () {
      expect(AppColors.background, const Color(0xFF0A0D13));
    });
    test('surface i surfaceVariant są chłodne', () {
      expect(AppColors.surface, const Color(0xFF121722));
      expect(AppColors.surfaceVariant, const Color(0xFF1A2130));
    });
    test('teksty i border w chłodnych odcieniach', () {
      expect(AppColors.textPrimary, const Color(0xFFF5F7FB));
      expect(AppColors.textSecondary, const Color(0xFF8A94A8));
      expect(AppColors.textMuted, const Color(0xFF5E687C));
      expect(AppColors.border, const Color(0xFF1F2635));
    });
    test('gradienty dopasowane do hero', () {
      expect(AppColors.gradientTop, const Color(0xFF0A0D13));
      expect(AppColors.gradientHero, const Color(0xFF141B28));
    });
    test('surfaceGlass jest półprzezroczyste', () {
      expect(AppColors.surfaceGlass.a, closeTo(0.85, 0.02));
    });
  });
}
