import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/typing_screen.dart';
import 'services/auth_repository.dart';
import 'services/audio_service.dart';
import 'services/dictionary_repository.dart';
import 'services/remote_statistics_service.dart';
import 'services/statistics_repository.dart';
import 'services/subscription_repository.dart';
import 'state/auth_controller.dart';
import 'state/subscription_controller.dart';
import 'state/typing_controller.dart';
import 'state/statistics_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.hasSupabaseConfig) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  } else {
    debugPrint('Supabase 配置缺失，认证功能将不可用。');
  }
  runApp(const LoopraApp());
}

class LoopraApp extends StatelessWidget {
  const LoopraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DictionaryRepository>(create: (_) => DictionaryRepository()),
        Provider<AudioService>(
          create: (_) => AudioService(),
          dispose: (_, AudioService service) => service.dispose(),
        ),
        Provider<SupabaseClient?>(
          create: (_) {
            if (!AppConfig.hasSupabaseConfig) {
              return null;
            }
            try {
              return Supabase.instance.client;
            } catch (_) {
              return null;
            }
          },
        ),
        Provider<AuthRepository>(
          create: (BuildContext context) => AuthRepository(
            client: context.read<SupabaseClient?>(),
          ),
        ),
        ChangeNotifierProvider<AuthController>(
          create: (BuildContext context) {
            final AuthController controller = AuthController(
              context.read<AuthRepository>(),
            );
            unawaited(controller.initialise());
            return controller;
          },
        ),
        Provider<RemoteStatisticsService>(
          create: (BuildContext context) => RemoteStatisticsService(
            client: context.read<SupabaseClient?>(),
          ),
        ),
        Provider<SubscriptionRepository>(
          create: (_) => SubscriptionRepository(),
          dispose: (_, SubscriptionRepository repository) => repository.dispose(),
        ),
        ChangeNotifierProvider<SubscriptionController>(
          create: (BuildContext context) {
            final SubscriptionController controller = SubscriptionController(
              context.read<SubscriptionRepository>(),
              context.read<AuthController>(),
            );
            unawaited(controller.initialise());
            return controller;
          },
        ),
        Provider<StatisticsRepository>(
          create: (BuildContext context) => StatisticsRepository(
            remoteService: context.read<RemoteStatisticsService>(),
            userIdProvider: () => context.read<AuthController>().user?.id,
            canSyncProvider: () {
              final AuthController auth = context.read<AuthController>();
              final SubscriptionController subscription = context.read<SubscriptionController>();
              return auth.isLoggedIn && subscription.canSync;
            },
          ),
        ),
        ChangeNotifierProvider<StatisticsController>(
          create: (BuildContext context) {
            final StatisticsController controller = StatisticsController(
              context.read<StatisticsRepository>(),
              authController: context.read<AuthController>(),
              subscriptionController: context.read<SubscriptionController>(),
            );
            unawaited(controller.initialise());
            return controller;
          },
        ),
        ChangeNotifierProvider<TypingController>(
          create: (BuildContext context) => TypingController(
            context.read<DictionaryRepository>(),
            context.read<AudioService>(),
            context.read<StatisticsController>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Loopra',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const TypingScreen(),
      ),
    );
  }
}
