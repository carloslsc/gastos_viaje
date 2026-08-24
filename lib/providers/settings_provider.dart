import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';
import '../services/widget_service.dart';

const _kPremiumId         = 'nivela_premium';
const _kUltimateMonthlyId = 'nivela_ultimate_monthly';
const _kUltimateAnnualId  = 'nivela_ultimate_annual';

enum AppLanguage { es, en, fr, zh, ja, ko, ru, de, it }

class SettingsProvider extends ChangeNotifier {
  Color _accentColor = AppTheme.orange;
  AppStyle _style = AppStyle.dark;
  AppLanguage _language = AppLanguage.es;
  bool _isPremium = false;
  bool _isUltimate = false;
  bool _purchasePending = false;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Color get accentColor => _accentColor;
  AppStyle get style => _style;
  AppLanguage get language => _language;
  bool get isPremium => _isPremium;
  bool get isUltimate => _isUltimate;
  bool get hasAnyPremium => _isPremium || _isUltimate;
  bool get purchasePending => _purchasePending;

  AppStrings get strings => switch (_language) {
    AppLanguage.es => AppStrings.es,
    AppLanguage.en => AppStrings.en,
    AppLanguage.fr => AppStrings.fr,
    AppLanguage.zh => AppStrings.zh,
    AppLanguage.ja => AppStrings.ja,
    AppLanguage.ko => AppStrings.ko,
    AppLanguage.ru => AppStrings.ru,
    AppLanguage.de => AppStrings.de,
    AppLanguage.it => AppStrings.it,
  };
  ThemeData get theme => AppTheme.build(accent: _accentColor, style: _style);

  static const _keyColor    = 'settings_accent';
  static const _keyStyle    = 'settings_style';
  static const _keyLang     = 'settings_lang';
  static const _keyPremium  = 'settings_premium';
  static const _keyUltimate = 'settings_ultimate';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final v = prefs.getInt(_keyColor);
    if (v != null) {
      final a = (v >> 24) & 0xFF;
      final r = (v >> 16) & 0xFF;
      final g = (v >> 8) & 0xFF;
      final b = v & 0xFF;
      _accentColor = Color.fromARGB(a, r, g, b);
    }

    if (prefs.containsKey(_keyStyle)) {
      final idx = prefs.getInt(_keyStyle)!;
      _style = AppStyle.values[idx.clamp(0, AppStyle.values.length - 1)];
    } else {
      final brightness = PlatformDispatcher.instance.platformBrightness;
      _style = brightness == Brightness.dark ? AppStyle.dark : AppStyle.light;
      await prefs.setInt(_keyStyle, _style.index);
    }

    if (prefs.containsKey(_keyLang)) {
      final idx = prefs.getInt(_keyLang)!;
      _language = AppLanguage.values[idx.clamp(0, AppLanguage.values.length - 1)];
    } else {
      _language = _detectLanguage(PlatformDispatcher.instance.locale);
      await prefs.setInt(_keyLang, _language.index);
    }

    _isPremium  = prefs.getBool(_keyPremium)  ?? false;
    _isUltimate = prefs.getBool(_keyUltimate) ?? false;

    _initPurchases();
  }

  // ── In-app purchase setup ─────────────────────────────
  void _initPurchases() {
    if (kIsWeb) return;
    _purchaseSub?.cancel();
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _purchaseSub?.cancel(),
      onError: (_) {},
    );
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> updates) async {
    for (final p in updates) {
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }

      if (p.productID == _kPremiumId) {
        switch (p.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await setPremium(true);
            _purchasePending = false;
          case PurchaseStatus.pending:
            _purchasePending = true;
          case PurchaseStatus.error:
          case PurchaseStatus.canceled:
            _purchasePending = false;
        }
      } else if (p.productID == _kUltimateMonthlyId ||
                 p.productID == _kUltimateAnnualId) {
        switch (p.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await setUltimate(true);
            _purchasePending = false;
          case PurchaseStatus.pending:
            _purchasePending = true;
          case PurchaseStatus.error:
          case PurchaseStatus.canceled:
            _purchasePending = false;
        }
      }
    }
    notifyListeners();
  }

  Future<void> _buyProduct(String productId) async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return;

    final response = await InAppPurchase.instance.queryProductDetails({productId});
    if (response.productDetails.isEmpty) return;

    _purchasePending = true;
    notifyListeners();

    final param = PurchaseParam(productDetails: response.productDetails.first);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  Future<void> buyPremium()          => _buyProduct(_kPremiumId);
  Future<void> buyUltimateMonthly()  => _buyProduct(_kUltimateMonthlyId);
  Future<void> buyUltimateAnnual()   => _buyProduct(_kUltimateAnnualId);

  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  // ── Settings mutations ────────────────────────────────
  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColor, color.toARGB32());
    WidgetService.triggerUpdate();
  }

  Future<void> setStyle(AppStyle s) async {
    _style = s;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStyle, s.index);
    WidgetService.triggerUpdate();
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPremium, value);
    WidgetService.triggerUpdate();
  }

  Future<void> setUltimate(bool value) async {
    _isUltimate = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUltimate, value);
    WidgetService.triggerUpdate();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLang, lang.index);
    WidgetService.triggerUpdate();
  }

  static AppLanguage _detectLanguage(Locale locale) => switch (locale.languageCode) {
    'es' => AppLanguage.es,
    'en' => AppLanguage.en,
    'fr' => AppLanguage.fr,
    'zh' => AppLanguage.zh,
    'ja' => AppLanguage.ja,
    'ko' => AppLanguage.ko,
    'ru' => AppLanguage.ru,
    'de' => AppLanguage.de,
    'it' => AppLanguage.it,
    _   => AppLanguage.en,
  };

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
