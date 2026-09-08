import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import 'no_internet_screen.dart';

class ConnectivityGuard extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityGuard({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ConnectivityGuard> createState() => _ConnectivityGuardState();
}

class _ConnectivityGuardState extends ConsumerState<ConnectivityGuard> {
  bool _dismissedTemporarily = false;

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityStateProvider);

    // If online, reset dismissed state so next offline drop will show the screen again
    if (isOnline && _dismissedTemporarily) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _dismissedTemporarily = false;
          });
        }
      });
    }

    return Stack(
      children: [
        widget.child,

        // If offline and not dismissed, show full-screen meme error page
        if (!isOnline && !_dismissedTemporarily)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: NoInternetScreen(
                onDismiss: () {
                  setState(() {
                    _dismissedTemporarily = true;
                  });
                },
                showDismissButton: true,
              ),
            ),
          ),
      ],
    );
  }
}
