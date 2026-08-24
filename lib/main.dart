import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'providers/trip_provider.dart';
import 'providers/settings_provider.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }
  final tripProvider = TripProvider();
  final settingsProvider = SettingsProvider();
  await Future.wait([tripProvider.load(), settingsProvider.load()]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: tripProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: const NivelaApp(),
    ),
  );
}

class NivelaApp extends StatelessWidget {
  const NivelaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Nivela',
      debugShowCheckedModeBanner: false,
      theme: settings.theme,
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final trip = context.read<TripProvider>().activeTrip;
      WidgetService.update(trip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final accent = Theme.of(context).colorScheme.primary;

    if (!provider.loaded) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: accent),
        ),
      );
    }

    if (!provider.hasActive) {
      return const SetupScreen();
    }

    return const HomeScreen();
  }
}
