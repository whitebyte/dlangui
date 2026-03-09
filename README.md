Dlang UI
========

Cross platform GUI for D. Widgets, layouts, styles, themes, unicode, i18n, OpenGL based acceleration.

![screenshot](http://buggins.github.io/dlangui/screenshots/screenshot-example1-windows.png "Screenshot of widgets demo app example1")

Main features:

* Cross-platform: Windows and Linux (SDL2 backend)
* Inspired by Android UI API (layouts, styles, two-phase layout)
* Customizable UI themes and styles
* Internationalization support
* Hardware acceleration via OpenGL
* Non thread-safe — all UI operations must be performed on a single thread
* Simple 3D scene engine

D compiler versions supported
-----------------------------

Requires DMD frontend 2.100.2 or newer.

Widgets
-------

List of widgets, layouts and other components is available in the [Wiki](https://github.com/buggins/dlangui/wiki#widgets).

Resources
---------

Resources like fonts and images use reference counting. Always destroy widgets to free resources.

* FontManager: provides access to fonts
* Images: `.png` or `.jpg`; filenames ending in `.9.png` are treated as nine-patch images
* StateDrawables: `.xml` files describing drawables chosen based on widget state (Android drawable XML format)
* `imageCache`: caches decoded images
* `drawableCache`: provides access by resource ID to drawables in resource directories

Styles and Themes
-----------------

* Theme is a container for styles, loaded from an XML resource file
* Styles are accessible by string ID and support inheritance
* State sub-styles allow appearance to change dynamically based on widget state
* Default theme resembles Visual Studio 2013
* Resources can be embedded into the executable or loaded from external directories at runtime

Build
-----

```sh
git clone --recursive https://github.com/buggins/dlangui.git
cd dlangui/examples/example1
dub run --build=release
```

Linux dependencies:

```sh
sudo apt-get install libsdl2-dev
# freetype, opengl, fontconfig loaded at runtime
```

Windows builds use SDL2 + OpenGL. FreeType is optional; Win32 font API is used as fallback.

Third party components
----------------------

* `bindbc-opengl` — OpenGL support
* `bindbc-freetype` — FreeType font rendering
* `bindbc-sdl` — SDL2 windowing and input
* `dxml` — XML parsing for themes and drawables
* `stb_image` (bundled) — image decoding (PNG, JPEG, BMP, TGA)
* `inilike`, `icontheme` — Linux desktop integration
