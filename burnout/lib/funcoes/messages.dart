// arquivo: messages.dart
import 'package:get/get.dart';
 // Importa todas as traduções de um único arquivo
import '../traducoes/traducoes.dart';

class Messages extends Translations {
      @override
      Map<String, Map<String, String>> get keys => {
            'pt_BR': getBrazilTranslationss(),
            'pt_PT': getPortugueseTranslations(),
            "en": getEnglishTranslations(),
            "sq": getAlbaniamTranslations(),
            "ar": getArabicTranslations(),
            "zh_TW": getChineseTradicionalTranslations(),
            "zh_CN": getChineseSimplificadoTranslations(),
            "ko": getKoreanTranslations(),
            "hr": getCroatianTranslations(),
            "cs": getCzechTranslations(),
            "da": getDanishTranslations(),
            "nl": getDutchTranslations(),
            "fi": getFinnishTranslations(),
            "fr": getFrenchTranslations(),
            "de": getGermanTranslations(),
            "el": getGreekTranslations(),
            "hi": getHindiTranslations(),
            "hu": getHungarianTranslations(),
            "is": getIcelandicTranslations(),
            "id": getIndonesianTranslations(),
            "it": getItalianTranslations(),
            "ja": getJaponeseTranslations(),
            "lv": getLatvianTranslations(),
            "lt": getLithuanianTranslations(),
            "ms": getMalayTranslations(),
            "mr": getMarathiTranslations(),
            "fa": getPersianTranslations(),
            "pl": getPolishTranslations(),
            "ro": getRomanianTranslations(),
            "ru": getRussianTranslations(),
            "sk": getSlovakTranslations(),
            "sl": getSlovenianTranslations(),
            "es": getSpanishTranslations(),
            "sv": getSwedishTranslations(),
            "ta": getTamilTranslations(),
            "te": getTeluguTranslations(),
            "th": getThaiTranslations(),
            "tr": getTurkishTranslations(),
            "uk": getUkrainianTranslations(),
            "vi": getVietnamitaTranslations(),
            "no": getNoruaguesTranslations(),
            "nb": getNoruaguesTranslations(),
            "ur": getUrduTranslations(),
            "he": getHebrewTranslations(),
      };
}
