import 'package:flutter_test/flutter_test.dart';
import 'package:planar/utils/app_icons.dart';
import 'package:planar/utils/search/icon_keywords.dart';

void main() {
  group('Icon Consistency Tests', () {
    test('All AppIcons have corresponding keywords', () {
      final allIcons = AppIcons.allIcons;
      final allKeywords = IconKeywords.keywords;

      final missingKeywords = <String>[];

      for (final iconName in allIcons.keys) {
        if (!allKeywords.containsKey(iconName)) {
          missingKeywords.add(iconName);
        }
      }

      if (missingKeywords.isNotEmpty) {
        fail('The following icons are missing from IconKeywords:\n'
            '${missingKeywords.join(', ')}');
      }
    });

    test('All IconKeywords exist in AppIcons', () {
      final allIcons = AppIcons.allIcons;
      final allKeywords = IconKeywords.keywords;

      final extraKeywords = <String>[];

      for (final keywordKey in allKeywords.keys) {
        if (!allIcons.containsKey(keywordKey)) {
          extraKeywords.add(keywordKey);
        }
      }

      if (extraKeywords.isNotEmpty) {
        fail('The following keys in IconKeywords do not exist in AppIcons:\n'
            '${extraKeywords.join(', ')}');
      }
    });

    test('Keywords are not empty', () {
      final allKeywords = IconKeywords.keywords;

      final emptyKeywords = <String>[];

      allKeywords.forEach((key, keywords) {
        if (keywords.isEmpty) {
          emptyKeywords.add(key);
        }
      });

      if (emptyKeywords.isNotEmpty) {
        fail('The following icons have empty keyword lists:\n'
            '${emptyKeywords.join(', ')}');
      }
    });
  });
}
