import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app services with error handling
  try {
    await bootstrap();
  } catch (e, stackTrace) {
    // If bootstrap fails, show error screen instead of black screen
    debugPrint('Bootstrap failed: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to initialize app', style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                Text('$e', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 32),
                ElevatedButton(onPressed: () => main(), child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Run the app wrapped in ProviderScope for Riverpod
  runApp(const ProviderScope(child: NovaApp()));
}
