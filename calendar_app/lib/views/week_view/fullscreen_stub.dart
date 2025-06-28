// Stub implementation for fullscreen functionality
// This is the fallback when neither web nor mobile specific implementations are available

void toggleFullscreen() {
  throw UnsupportedError('Fullscreen is not supported on this platform');
}

bool get isFullscreen => false; 