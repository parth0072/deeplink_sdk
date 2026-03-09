import 'package:flutter/material.dart';
import 'package:deeplink_sdk/deeplink_sdk.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Step 1: Configure the SDK ───────────────────────────────────────────
  // Call once before runApp(). Replace with your real API key and domain.
  await Deeplink.configure(
    apiKey: '7f9d682990f7b0d1502906357a35cd5f886293f8cf2377d3',
    domain: 'https://deeplinkbe-production-5e4b.up.railway.app',
  );

  // ── Step 2: Fetch deferred deep link on first install ──────────────────
  // Matches the install fingerprint against the click that led the user here.
  // Call once after onboarding completes in production.
  final data = await Deeplink.getInitData();
  if (data != null) {
    debugPrint('[Deeplink] Matched install!');
    debugPrint('  → destination : ${data.destinationUrl}');
    debugPrint('  → androidUrl  : ${data.androidUrl}');
    debugPrint('  → metadata    : ${data.metadata}');
  } else {
    debugPrint('[Deeplink] No deferred deep link found.');
  }

  runApp(const SampleApp());
}

class SampleApp extends StatelessWidget {
  const SampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deeplink Sample',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      // ── Step 3: Handle incoming deep links ───────────────────────────────
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null) {
          final link = Deeplink.handleIncomingUri(uri);
          if (link != null) {
            debugPrint('[Deeplink] Incoming URI: $uri');
            debugPrint('  → segments : ${link.pathSegments}');
            debugPrint('  → params   : ${link.params}');
          }
        }
        return null;
      },
    );
  }
}
