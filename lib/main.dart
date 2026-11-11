import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'state/pos_state.dart';

const Color shopPosGreen = Color(0xFF39FF88);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = PosState();
  await state.load();
  runApp(ShopPosApp(state: state));
}

class ShopPosApp extends StatelessWidget {
  const ShopPosApp({super.key, required this.state});

  final PosState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PosState>.value(
      value: state,
      child: MaterialApp(
        title: 'ShopPOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: shopPosGreen,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const MainShell(),
      ),
    );
  }
}
