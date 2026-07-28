import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/theme/app_colors.dart';

void main() {
  group('AppColors — paleta Steel Blue', () {
    test('primary to niebieski akcent', () {
      expect(AppColors.primary, const Color(0xFF2563EB));
    });
    test('primaryVariant to jaśniejszy niebieski', () {
      expect(AppColors.primaryVariant, const Color(0xFF3B82F6));
    });
    test('onPrimary to biały (kontrast na niebieskim)', () {
      expect(AppColors.onPrimary, const Color(0xFFFFFFFF));
    });
    test('background to ciemny grafit-niebieski', () {
      expect(AppColors.background, const Color(0xFF0B0E14));
    });
    test('surface i surfaceVariant są chłodne', () {
      expect(AppColors.surface, const Color(0xFF141820));
      expect(AppColors.surfaceVariant, const Color(0xFF1E2433));
    });
    test('teksty i border w chłodnych odcieniach', () {
      expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
      expect(AppColors.textSecondary, const Color(0xFF9CA3AF));
      expect(AppColors.textMuted, const Color(0xFF6B7280));
      expect(AppColors.border, const Color(0xFF2A3344));
    });
    test('gradienty dopasowane do hero', () {
      expect(AppColors.gradientTop, const Color(0xFF0B0E14));
      expect(AppColors.gradientHero, const Color(0xFF141B28));
    });
    test('surfaceGlass jest półprzezroczyste', () {
      expect(AppColors.surfaceGlass.a, closeTo(0.85, 0.02));
    });
  });
}
