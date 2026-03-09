# Changelog

### Removed backends

- **DSFML** — removed `src/dlangui/platforms/dsfml/`, `sfml` dub configuration, and `dsfml` dependency.
  Was never finished or production-ready, no clear benefits over SDL.

- **Console/TUI** — removed `src/dlangui/platforms/ansi_console/`, `console` dub configuration, and all `WIDGET_STYLE_CONSOLE` conditional code.
  Again, probably was fun to write, but TUIs in general is a completely different story, and not the one I want to have. It pervaded the codebase with `static if (WIDGET_STYLE_CONSOLE)` branches in rendering, theming, and layout code. A terminal UI has fundamentally different layout assumptions from a GUI, making it a poor fit as a configuration of the same widget tree.

- **Android** — removed `src/dlangui/platforms/android/`, `android/` build directory, `examples/android/`, and all `version(Android)` conditional code.
  D on Android has never had a real production story. The LDC-based toolchain required for ARM cross-compilation is cumbersome, the Android ecosystem moves fast, and there are no known D apps in the Play Store. DlangUI's heydays were circa '15-16. In 2026 it's just dead weight

### Dependencies

- Replaced `arsd-official:dom` with `dxml` for XML parsing (theme and drawable files).
- Replaced `arsd-official:image_files` with bundled `stb_image` (single-header C library, compiled via pre-build command).
- 
  arsd v12+ targets the opend compiler fork and is no longer maintained for mainline DMD. 

### Font rendering - Freetype is always enabled

In 2015 Win32 GDI fallback made sense. In 2026, I don't think so.
