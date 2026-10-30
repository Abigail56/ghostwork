import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'router.dart';
import 'state/providers.dart';

void main() => runApp(const ProviderScope(child: GhostWorkApp()));

class GhostWorkApp extends ConsumerWidget {
  const GhostWorkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionProvider);
    final compact = ref.watch(compactProvider);
    return MaterialApp.router(
      title: 'GhostWork',
      debugShowCheckedModeBanner: false,
      theme: buildTheme().copyWith(visualDensity: compact ? VisualDensity.compact : VisualDensity.standard),
      routerConfig: ref.watch(routerProvider),
      // Appearance → Motion: "reduce" forces reduced motion; "system" follows the OS.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: reduceMotion ?? media.disableAnimations),
          child: child!,
        );
      },
    );
  }
}
