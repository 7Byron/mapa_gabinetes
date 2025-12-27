import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/ad_logger.dart';
import '../ad_manager.dart';
import '../../funcoes/rotas_paginas.dart';

class SmartPreloadingService extends GetxService {
  static SmartPreloadingService get to => Get.find<SmartPreloadingService>();

  final GetStorage _storage = GetStorage();
  final Map<String, UserPattern> _patterns = {};
  final Map<String, DateTime> _lastVisits = {};
  final Map<String, int> _visitCounts = {};
  final List<String> _sessionPages = [];

  static const Duration preloadWindow = Duration(minutes: 5);
  static const Duration sessionTimeout = Duration(minutes: 30);
  static const int minVisitsForPattern = 3;
  static const int maxPatternsStored = 50;

  String? _currentPage;
  DateTime? _sessionStart;
  Timer? _preloadTimer;
  Timer? _sessionTimer;

  @override
  void onInit() {
    super.onInit();
    _loadStoredPatterns();
    _startSession();
    AdLogger.info('SmartPreloading', 'Service initialized');
  }

  void _startSession() {
    _sessionStart = DateTime.now();
    _sessionPages.clear();

    _sessionTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => _savePatterns());

    AdLogger.info('SmartPreloading', 'New session started');
  }

  void onPageVisit(String pageName) {
    if (pageName.isEmpty) return;

    final now = DateTime.now();

    _currentPage = pageName;
    _lastVisits[pageName] = now;
    _visitCounts[pageName] = (_visitCounts[pageName] ?? 0) + 1;

    _sessionPages.add(pageName);

    _analyzeAndPreload(pageName);

    AdLogger.info('SmartPreloading', 'Page visit registered: $pageName');
  }

  void _analyzeAndPreload(String currentPage) {
    _preloadTimer?.cancel();

    final predictedPages = _predictNextPages(currentPage);

    if (predictedPages.isNotEmpty) {
      _preloadTimer = Timer(const Duration(seconds: 2), () {
        _preloadForPages(predictedPages);
      });

      AdLogger.info('SmartPreloading',
          'Predicted next pages for $currentPage: ${predictedPages.take(3).join(", ")}');
    }

    _updatePatterns(currentPage);
  }

  List<String> _predictNextPages(String currentPage) {
    final predictions = <String>[];

    final pattern = _patterns[currentPage];
    if (pattern != null && pattern.isReliable) {
      predictions.addAll(pattern.getTopTransitions(3));
    }

    predictions.addAll(_getSessionPatterns(currentPage));

    predictions.addAll(_getMostVisitedPages(3));

    final uniquePredictions = predictions.toSet().toList();
    uniquePredictions.remove(currentPage);

    return uniquePredictions.take(5).toList();
  }

  List<String> _getSessionPatterns(String currentPage) {
    final patterns = <String>[];

    final recentPages = _sessionPages.length > 10
        ? _sessionPages.sublist(_sessionPages.length - 10)
        : _sessionPages;

    for (int i = 0; i < recentPages.length - 1; i++) {
      if (recentPages[i] == currentPage) {
        final nextPage = recentPages[i + 1];
        if (!patterns.contains(nextPage)) {
          patterns.add(nextPage);
        }
      }
    }

    return patterns;
  }

  List<String> _getMostVisitedPages(int count) {
    final sortedPages = _visitCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPages.take(count).map((e) => e.key).toList();
  }

  void _preloadForPages(List<String> pages) {
    if (!Get.isRegistered<AdManager>()) return;

    final adManager = AdManager.to;

    for (final page in pages.take(2)) {
      _preloadForPage(page, adManager);
    }
  }

  void _preloadForPage(String page, AdManager adManager) {
    final adType = _getAdTypeForPage(page);

    switch (adType) {
      case AdType.interstitial:
        if (!adManager.hasInterstitialAd) {
          adManager.loadInterstitialAd();
          AdLogger.info('SmartPreloading', 'Preloaded interstitial for $page');
        }
        break;
      case AdType.rewarded:
        adManager.loadRewardedAd();
        AdLogger.info('SmartPreloading', 'Preloaded rewarded for $page');
        break;
      case AdType.banner:
        // Banner é carregado sob demanda
        break;
    }
  }

  AdType _getAdTypeForPage(String page) {
    // Testes que NÃO usam anúncios intersticiais durante o teste
    const testsWithoutInterstitials = {
      RotasPaginas.testeDepressao,
      RotasPaginas.testeAnsiedade,
      RotasPaginas.testeAutoConfianca,
      RotasPaginas.testeRelacionamentos,
    };

    // Testes que usam anúncios intersticiais durante o teste
    const testRoutesWithInterstitials = {
      RotasPaginas.testeStress,
      RotasPaginas.testeStressAgravantes,
      RotasPaginas.testeRaiva,
      RotasPaginas.testeDependencia,
      RotasPaginas.testeAtitude,
      RotasPaginas.testeFelicidade,
      RotasPaginas.testePersonalidade,
      RotasPaginas.testeSorisso,
    };

    const resultRoutes = {
      RotasPaginas.resultadoDepressao,
      RotasPaginas.resultadoAnsiedade,
      RotasPaginas.resultadoTesteStress,
      RotasPaginas.resultadoTesteRaiva,
      RotasPaginas.resultadoTesteDependencia,
      RotasPaginas.resultadoTesteAtitude,
      RotasPaginas.resultadoTesteFelicidade,
      RotasPaginas.resultadoTestePersonalidade,
      RotasPaginas.resultadoRelacionamento,
      RotasPaginas.resultadoSorriso,
      RotasPaginas.resultadoAutoConfianca,
    };

    // Não pré-carrega intersticiais para testes que não os usam
    if (testsWithoutInterstitials.contains(page)) {
      return AdType.banner; // Apenas banner, sem intersticiais
    }

    // Pré-carrega intersticiais apenas para testes que os usam
    if (testRoutesWithInterstitials.contains(page) ||
        (page.startsWith('/teste') &&
            !testsWithoutInterstitials.contains(page))) {
      return AdType.interstitial;
    }

    if (resultRoutes.contains(page) || page.contains('resultado')) {
      return AdType.rewarded;
    }
    return AdType.banner;
  }

  void _updatePatterns(String currentPage) {
    final pattern = _patterns[currentPage] ?? UserPattern(page: currentPage);

    final pageIndex = _sessionPages.lastIndexOf(currentPage);
    if (pageIndex >= 0 && pageIndex < _sessionPages.length - 1) {
      final nextPage = _sessionPages[pageIndex + 1];
      pattern.addTransition(nextPage);
    }

    _patterns[currentPage] = pattern;

    if (_patterns.length > maxPatternsStored) {
      _cleanupOldPatterns();
    }
  }

  void _cleanupOldPatterns() {
    final sortedPatterns = _patterns.entries.toList()
      ..sort((a, b) =>
          a.value.totalTransitions.compareTo(b.value.totalTransitions));

    final toRemove = (sortedPatterns.length * 0.2).ceil();
    for (int i = 0; i < toRemove; i++) {
      _patterns.remove(sortedPatterns[i].key);
    }

    AdLogger.info('SmartPreloading', 'Cleaned up $toRemove old patterns');
  }

  void _loadStoredPatterns() {
    try {
      final patternsData = _storage.read<String>('user_patterns');
      final visitsData = _storage.read<String>('visit_counts');

      if (patternsData != null) {
        final Map<String, dynamic> decoded = jsonDecode(patternsData);
        for (final entry in decoded.entries) {
          _patterns[entry.key] = UserPattern.fromJson(entry.value);
        }
        AdLogger.info(
            'SmartPreloading', 'Loaded ${_patterns.length} stored patterns');
      }

      if (visitsData != null) {
        final Map<String, dynamic> decoded = jsonDecode(visitsData);
        _visitCounts.clear();
        decoded.forEach((key, value) {
          _visitCounts[key] = value as int;
        });
        AdLogger.info(
            'SmartPreloading', 'Loaded ${_visitCounts.length} visit counts');
      }
    } catch (e) {
      AdLogger.error('SmartPreloading', 'Error loading patterns: $e');
    }
  }

  void _savePatterns() {
    try {
      final patternsJson = <String, dynamic>{};
      for (final entry in _patterns.entries) {
        patternsJson[entry.key] = entry.value.toJson();
      }
      _storage.write('user_patterns', jsonEncode(patternsJson));

      _storage.write('visit_counts', jsonEncode(_visitCounts));

      AdLogger.info('SmartPreloading', 'Patterns saved to storage');
    } catch (e) {
      AdLogger.error('SmartPreloading', 'Error saving patterns: $e');
    }
  }

  Map<String, dynamic> get statistics => {
        'total_patterns': _patterns.length,
        'total_pages_visited': _visitCounts.length,
        'session_pages': _sessionPages.length,
        'current_page': _currentPage,
        'session_duration_minutes': _sessionStart != null
            ? DateTime.now().difference(_sessionStart!).inMinutes
            : 0,
        'reliable_patterns': _patterns.values.where((p) => p.isReliable).length,
        'most_visited_pages': _getMostVisitedPages(5),
        'recent_session_pages': _sessionPages.length > 5
            ? _sessionPages.sublist(_sessionPages.length - 5)
            : _sessionPages,
      };

  void resetLearningData() {
    _patterns.clear();
    _visitCounts.clear();
    _sessionPages.clear();
    _storage.remove('user_patterns');
    _storage.remove('visit_counts');
    AdLogger.info('SmartPreloading', 'Learning data reset');
  }

  @override
  void onClose() {
    _preloadTimer?.cancel();
    _sessionTimer?.cancel();
    _savePatterns();
    AdLogger.info('SmartPreloading', 'Service closed');
    super.onClose();
  }
}

/// Representa um padrão de uso de uma página
class UserPattern {
  final String page;
  final Map<String, int> transitions = {};
  int totalTransitions = 0;
  DateTime lastUpdated = DateTime.now();

  UserPattern({required this.page});

  /// Adiciona uma transição para outra página
  void addTransition(String toPage) {
    transitions[toPage] = (transitions[toPage] ?? 0) + 1;
    totalTransitions++;
    lastUpdated = DateTime.now();
  }

  /// Verifica se o padrão é confiável (tem dados suficientes)
  bool get isReliable =>
      totalTransitions >= SmartPreloadingService.minVisitsForPattern;

  /// Obtém top transições ordenadas por frequência
  List<String> getTopTransitions(int count) {
    if (transitions.isEmpty) return [];

    final sorted = transitions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(count).map((e) => e.key).toList();
  }

  /// Obtém probabilidade de transição para uma página
  double getTransitionProbability(String toPage) {
    if (totalTransitions == 0) return 0.0;
    return (transitions[toPage] ?? 0) / totalTransitions;
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'transitions': transitions,
        'totalTransitions': totalTransitions,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory UserPattern.fromJson(Map<String, dynamic> json) {
    final pattern = UserPattern(page: json['page']);
    pattern.transitions
        .addAll(Map<String, int>.from(json['transitions'] ?? {}));
    pattern.totalTransitions = json['totalTransitions'] ?? 0;
    pattern.lastUpdated =
        DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String());
    return pattern;
  }
}

enum AdType {
  banner,
  interstitial,
  rewarded,
}
