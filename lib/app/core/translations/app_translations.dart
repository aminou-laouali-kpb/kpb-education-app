import 'package:get/get.dart';

import 'app_translations_en.dart';
import 'app_translations_fr.dart';

export 'app_translations_en.dart';
export 'app_translations_fr.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => const {
        'fr': appTranslationsFr,
        'en': appTranslationsEn,
      };
}
