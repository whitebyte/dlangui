// Written in the D programming language.

/**
This module contains image loading functions.

Currently uses FreeImage.

Usage of libpng is not feasible under linux due to conflicts of library and binding versions.

Synopsis:

----
import dlangui.graphics.images;

----

Copyright: Vadim Lopatin, 2014
License:   Boost License 1.0
Authors:   Vadim Lopatin, coolreader.org@gmail.com
*/
module dlangui.graphics.images;

public import dlangui.core.config;
static if (BACKEND_GUI):

import stb_image;

import dlangui.core.logger;
import dlangui.core.types;
import dlangui.graphics.colors;
import dlangui.graphics.drawbuf;
import dlangui.core.streams;
import std.path;
import std.conv : to;


/// load and decode image from file to ColorDrawBuf, returns null if loading or decoding is failed
ColorDrawBuf loadImage(string filename) {
    static import std.file;
    try {
        immutable ubyte[] data = cast(immutable ubyte[])std.file.read(filename);
        return loadImage(data, filename);
    } catch (Exception e) {
        Log.e("exception while loading image from file ", filename);
        Log.e(to!string(e));
        return null;
    }
}

/// load and decode image from input stream to ColorDrawBuf, returns null if loading or decoding is failed
ColorDrawBuf loadImage(immutable ubyte[] data, string filename) {
    Log.d("Loading image from file " ~ filename);

    import std.algorithm : endsWith;
    if (filename.endsWith(".xpm")) {
        import dlangui.graphics.xpm.reader : parseXPM;
        try {
            return parseXPM(data);
        }
        catch(Exception e) {
            Log.e("Failed to load image from file ", filename);
            Log.e(to!string(e));
            return null;
        }
    }

    int w, h, channels;
    ubyte* pixels = stbi_load_from_memory(data.ptr, cast(int)data.length, &w, &h, &channels, 4);
    if (!pixels) {
        Log.e("stb_image: failed to decode ", filename);
        return null;
    }
    scope(exit) stbi_image_free(pixels);
    ColorDrawBuf buf = new ColorDrawBuf(w, h);
    for (int j = 0; j < h; j++) {
        auto scanLine = buf.scanLine(j);
        for (int i = 0; i < w; i++) {
            ubyte* p = pixels + (j * w + i) * 4;
            scanLine[i] = makeRGBA(p[0], p[1], p[2], 255 - p[3]);
        }
    }
    return buf;
}
