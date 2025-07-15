// Web-specific fullscreen implementation using dart:html
import 'dart:html' as html;

void toggleFullscreen() {
  final element = html.document.documentElement!;
  if (html.document.fullscreenElement == null) {
    element.requestFullscreen();
  } else {
    html.document.exitFullscreen();
  }
}

bool get isFullscreen => html.document.fullscreenElement != null; 