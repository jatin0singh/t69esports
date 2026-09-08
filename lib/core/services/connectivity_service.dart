import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onStatusChanged;
});

final connectivityStateProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return ConnectivityNotifier(service);
});

class ConnectivityNotifier extends StateNotifier<bool> {
  final ConnectivityService _service;
  StreamSubscription<bool>? _subscription;

  ConnectivityNotifier(this._service) : super(true) {
    _init();
  }

  void _init() {
    _subscription = _service.onStatusChanged.listen((isOnline) {
      state = isOnline;
    });
    // Check initial status
    checkNow();
  }

  Future<bool> checkNow() async {
    final result = await _service.checkRealInternet();
    state = result;
    return result;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _lastStatus = true;
  bool get isOnline => _lastStatus;
  Stream<bool> get onStatusChanged => _statusController.stream;

  ConnectivityService() {
    _init();
  }

  void _init() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) async {
        final hasConnection = results.any(
          (r) => r != ConnectivityResult.none,
        );

        if (!hasConnection) {
          _updateStatus(false);
        } else {
          // Verify actual reachability
          final canReach = await checkRealInternet();
          _updateStatus(canReach);
        }
      },
    );

    // Initial check
    checkRealInternet().then(_updateStatus);
  }

  Future<bool> checkRealInternet() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasActiveInterface = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn,
      );

      if (!hasActiveInterface || results.every((r) => r == ConnectivityResult.none)) {
        _updateStatus(false);
        return false;
      }

      // Fast DNS lookup check to ensure true internet connectivity
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 1800));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        _updateStatus(true);
        return true;
      }
      _updateStatus(false);
      return false;
    } catch (_) {
      try {
        final fallback = await InternetAddress.lookup('1.1.1.1')
            .timeout(const Duration(milliseconds: 1200));
        final isOk = fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty;
        _updateStatus(isOk);
        return isOk;
      } catch (_) {
        _updateStatus(false);
        return false;
      }
    }
  }

  void _updateStatus(bool status) {
    if (_lastStatus != status) {
      _lastStatus = status;
      _statusController.add(status);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
