import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/typing_screen.dart';
import 'services/audio_service.dart';
import 'services/dictionary_repository.dart';
import 'state/typing_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        ChangeNotifierProvider<TypingController>(
          create: (BuildContext context) => TypingController(
            context.read<DictionaryRepository>(),
            context.read<AudioService>(),
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
