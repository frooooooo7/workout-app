import 'package:flutter/material.dart';

class SvgPathParser {
  static Path parsePath(String pathData) {
    if (pathData.isEmpty) return Path();

    final path = Path();
    var i = 0;
    var lastX = 0.0;
    var lastY = 0.0;

    while (i < pathData.length) {
      // Pomiń spacje i przecinki
      while (i < pathData.length && (pathData[i] == ' ' || pathData[i] == ',')) {
        i++;
      }

      if (i >= pathData.length) break;

      final cmd = pathData[i];
      i++;

      final params = _parseParams(pathData, i);
      i = params['nextIndex'] as int;
      final values = params['values'] as List<double>;

      switch (cmd) {
        case 'M':
        case 'm':
          if (values.length >= 2) {
            final x = cmd == 'M' ? values[0] : lastX + values[0];
            final y = cmd == 'M' ? values[1] : lastY + values[1];
            path.moveTo(x, y);
            lastX = x;
            lastY = y;
          }
          break;

        case 'L':
        case 'l':
          if (values.length >= 2) {
            final x = cmd == 'L' ? values[0] : lastX + values[0];
            final y = cmd == 'L' ? values[1] : lastY + values[1];
            path.lineTo(x, y);
            lastX = x;
            lastY = y;
          }
          break;

        case 'H':
        case 'h':
          if (values.isNotEmpty) {
            final x = cmd == 'H' ? values[0] : lastX + values[0];
            path.lineTo(x, lastY);
            lastX = x;
          }
          break;

        case 'V':
        case 'v':
          if (values.isNotEmpty) {
            final y = cmd == 'V' ? values[0] : lastY + values[0];
            path.lineTo(lastX, y);
            lastY = y;
          }
          break;

        case 'C':
        case 'c':
          if (values.length >= 6) {
            final cp1x = cmd == 'C' ? values[0] : lastX + values[0];
            final cp1y = cmd == 'C' ? values[1] : lastY + values[1];
            final cp2x = cmd == 'C' ? values[2] : lastX + values[2];
            final cp2y = cmd == 'C' ? values[3] : lastY + values[3];
            final x = cmd == 'C' ? values[4] : lastX + values[4];
            final y = cmd == 'C' ? values[5] : lastY + values[5];
            path.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
            lastX = x;
            lastY = y;
          }
          break;

        case 'Q':
        case 'q':
          if (values.length >= 4) {
            final cpx = cmd == 'Q' ? values[0] : lastX + values[0];
            final cpy = cmd == 'Q' ? values[1] : lastY + values[1];
            final x = cmd == 'Q' ? values[2] : lastX + values[2];
            final y = cmd == 'Q' ? values[3] : lastY + values[3];
            path.quadraticBezierTo(cpx, cpy, x, y);
            lastX = x;
            lastY = y;
          }
          break;

        case 'A':
        case 'a':
          // Uproszczona implementacja łuków - pomijamy flagę sweep
          if (values.length >= 7) {
            final x = cmd == 'A' ? values[5] : lastX + values[5];
            final y = cmd == 'A' ? values[6] : lastY + values[6];
            path.lineTo(x, y);
            lastX = x;
            lastY = y;
          }
          break;

        case 'Z':
        case 'z':
          path.close();
          break;
      }
    }

    return path;
  }

  static Map<String, dynamic> _parseParams(String pathData, int startIndex) {
    final values = <double>[];
    var i = startIndex;

    while (i < pathData.length) {
      // Pomiń spacje i przecinki
      while (i < pathData.length && (pathData[i] == ' ' || pathData[i] == ',')) {
        i++;
      }

      if (i >= pathData.length) break;

      // Jeśli trafimy na nową komendę, stop
      if (_isCommand(pathData[i])) break;

      final numStr = _parseNumber(pathData, i);
      if (numStr['number'] != null) {
        values.add(numStr['number'] as double);
        i = numStr['nextIndex'] as int;
      } else {
        break;
      }
    }

    return {'values': values, 'nextIndex': i};
  }

  static Map<String, dynamic> _parseNumber(String pathData, int startIndex) {
    var i = startIndex;
    final sb = StringBuffer();

    // Opcjonalny znak
    if (i < pathData.length && (pathData[i] == '+' || pathData[i] == '-')) {
      sb.write(pathData[i]);
      i++;
    }

    // Cyfry przed przecinkiem
    while (i < pathData.length && _isDigit(pathData[i])) {
      sb.write(pathData[i]);
      i++;
    }

    // Opcjonalny przecinek i cyfry
    if (i < pathData.length && pathData[i] == '.') {
      sb.write('.');
      i++;
      while (i < pathData.length && _isDigit(pathData[i])) {
        sb.write(pathData[i]);
        i++;
      }
    }

    // Opcjonalny notacja naukowa
    if (i < pathData.length && (pathData[i] == 'e' || pathData[i] == 'E')) {
      sb.write(pathData[i]);
      i++;
      if (i < pathData.length && (pathData[i] == '+' || pathData[i] == '-')) {
        sb.write(pathData[i]);
        i++;
      }
      while (i < pathData.length && _isDigit(pathData[i])) {
        sb.write(pathData[i]);
        i++;
      }
    }

    if (sb.isEmpty) {
      return {'number': null, 'nextIndex': startIndex};
    }

    try {
      return {'number': double.parse(sb.toString()), 'nextIndex': i};
    } catch (e) {
      return {'number': null, 'nextIndex': startIndex};
    }
  }

  static bool _isDigit(String char) => char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

  static bool _isCommand(String char) {
    const commands = 'MmLlHhVvCcSsQqTtAaZz';
    return commands.contains(char);
  }
}
