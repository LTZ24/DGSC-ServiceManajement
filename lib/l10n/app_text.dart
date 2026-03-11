import 'package:flutter/widgets.dart';

extension AppTextX on BuildContext {
  bool get isEnglish => Localizations.localeOf(this).languageCode == 'en';

  String tr(String idText, String enText) {
    return isEnglish ? enText : idText;
  }
}
