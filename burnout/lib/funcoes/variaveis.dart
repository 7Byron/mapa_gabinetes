import 'platform_utils.dart';

enum DialogAction { yes }

class Variaveis {
  static String get appChat => platformIsAndroid()
      ? 'https://play.google.com/store/apps/details?id=com.byronsd.chat_psychological_help'
      : 'https://apps.apple.com/us/app/chat-ajuda-me/id1610853087';

  static String get listaTodosApps => platformIsAndroid()
      ? 'https://play.google.com/store/search?q=from%3A%20%22Byron%20System%20Developer%22'
      : 'https://apps.apple.com/us/developer/f-r-cuidados-de-saude-lda/id1568299411';

  static const String sproutsschoolsSite = "https://sproutsschools.com/";
  static const String ilustVideo =
      "https://www.youtube.com/watch?v=IB1FVbo8TSs";
  static const String siteBSD = "https://www.byronsd.com/";
  static const String worldHappinessReport =
      "https://public.tableau.com/views/WorldHappinessReport2022final/Figure2_1?:embed=y&:embed_code_version=3&:loadOrderID=0&:display_count=y&:origin=viz_share_link";
  static const String anxietyWiki =
      "https://en.wikipedia.org/wiki/Beck_Anxiety_Inventory";
  static const String depressionWiki =
      "https://en.wikipedia.org/wiki/Beck_Depression_Inventory";
  static const String healthyLifestyleTips =
      "https://www.byronsd.com/2021/08/healthy-lifestyle.html";
  static const String whoMentalHealth =
      "https://www.who.int/news-room/fact-sheets/detail/mental-disorders";
  static const String mayoClinicDepression =
      "https://www.mayoclinic.org/diseases-conditions/depression/symptoms-causes/syc-20356007";
}
