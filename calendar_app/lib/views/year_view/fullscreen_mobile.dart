// Mobile-specific fullscreen implementation using SystemChrome
import 'package:flutter/services.dart';

bool _isImmersive = false;

void toggleFullscreen() {
  if (_isImmersive) {
    // Exit immersive mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _isImmersive = false;
  } else {
    // Enter immersive mode (less sensitive than immersiveSticky)
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersive,
      overlays: [],
    );
    _isImmersive = true;
  }
}

bool get isFullscreen => _isImmersive; 