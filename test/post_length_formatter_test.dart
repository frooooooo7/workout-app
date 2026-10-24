import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/post_draft.dart';
import 'package:gym/features/training/presentation/widgets/workout_summary/share_workout_sheet.dart';

TextEditingValue _value(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

void main() {
  final title = PostLengthFormatter(postTitleMaxLength, postTitleLength);
  final body = PostLengthFormatter(postBodyMaxLength, postBodyLength);

  test('title is limited in code points, like the server', () {
    // 41 flag = 41 grafemów, ale 82 punkty kodowe.
    final flags = '🇵🇱' * 41;
    final result = title.formatEditUpdate(_value(''), _value(flags));
    expect(postTitleLength(result.text), 80);
    expect(result.text, '🇵🇱' * 40);
  });

  test('a paste is cut on a grapheme boundary', () {
    final text = '${'a' * 79}💪🏼';
    final result = title.formatEditUpdate(_value(''), _value(text));
    expect(result.text, 'a' * 79);
  });

  test('body is limited in UTF-16 units, like the server note', () {
    final text = '💪' * 1001; // 2002 jednostki UTF-16
    final result = body.formatEditUpdate(_value(''), _value(text));
    expect(result.text, '💪' * 1000);
  });

  test('an existing text over the limit is never cut, only shortened', () {
    final long = 'x' * 2100;
    final shorter = 'x' * 2099;
    expect(body.formatEditUpdate(_value(long), _value(shorter)).text, shorter);
    expect(body.formatEditUpdate(_value(long), _value('${long}y')).text, long);
  });
}
