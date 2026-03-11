module widgets.autocomplete;

import dlangui;
import dlangui.widgets.autocomplete;

class AutoCompleteExample : VerticalLayout {
    this(string ID) {
        super(ID);
        padding(Rect(12, 12, 12, 12));

        addChild(new TextWidget(null, "AutoCompleteEdit: type to filter suggestions from the dropdown"d));

        // HTTP header names as demo suggestions
        auto httpHeaders = [
            "Accept"d, "Accept-Charset"d, "Accept-Encoding"d, "Accept-Language"d,
            "Authorization"d, "Cache-Control"d, "Connection"d, "Content-Encoding"d,
            "Content-Length"d, "Content-Type"d, "Cookie"d, "Date"d,
            "ETag"d, "Expect"d, "Expires"d, "From"d,
            "Host"d, "If-Match"d, "If-Modified-Since"d, "If-None-Match"d,
            "Last-Modified"d, "Location"d, "Origin"d, "Pragma"d,
            "Referer"d, "Server"d, "Set-Cookie"d, "Transfer-Encoding"d,
            "User-Agent"d, "Vary"d, "Via"d, "WWW-Authenticate"d,
        ];

        auto edit1 = new AutoCompleteEdit("ac_http", httpHeaders);
        edit1.layoutWidth(FILL_PARENT);
        addChild(edit1);

        addChild(new TextWidget(null, "AutoCompleteEdit: programming language names"d));

        auto langs = [
            "C"d, "C++"d, "C#"d,
            "D"d, "Dart"d,
            "Elixir"d, "Erlang"d,
            "F#"d, "Fortran"d,
            "Go"d, "Groovy"d,
            "Haskell"d,
            "Java"d, "JavaScript"d, "Julia"d,
            "Kotlin"d,
            "Lua"d,
            "Nim"d,
            "OCaml"d,
            "Pascal"d, "Perl"d, "PHP"d, "Python"d,
            "R"d, "Ruby"d, "Rust"d,
            "Scala"d, "Swift"d,
            "TypeScript"d,
            "Zig"d,
        ];

        auto edit2 = new AutoCompleteEdit("ac_lang", langs);
        edit2.layoutWidth(FILL_PARENT);
        addChild(edit2);

        addChild(new TextWidget(null,
            "Keyboard: type to filter · Down — move to list · Enter — accept · Esc — dismiss"d));

        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    }
}
