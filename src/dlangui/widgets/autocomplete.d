/**
AutoComplete edit widget.

An EditLine that shows a filtered suggestion popup as the user types.

Synopsis:
----
import dlangui.widgets.autocomplete;

auto edit = new AutoCompleteEdit("myEdit", ["Accept"d, "Content-Type"d, "Authorization"d]);
----
*/
module dlangui.widgets.autocomplete;

import dlangui.widgets.widget;
import dlangui.widgets.styles;
import dlangui.widgets.editors;
import dlangui.widgets.lists;
import dlangui.widgets.popup;
import dlangui.core.events;
import std.uni : toLower;
import std.algorithm : filter, startsWith;
import std.array : array;
import std.conv : to;

/**
  An EditLine with a filtered suggestion dropdown.

  While the user types, suggestions are filtered by case-insensitive prefix
  match and displayed in a popup below the widget. The user can:
  - Keep typing to narrow suggestions
  - Click a suggestion to accept it
  - Press Down to move focus into the list, then Up/Down/Enter to navigate
  - Press Escape to dismiss the popup without selecting
*/
class AutoCompleteEdit : EditLine {
    private dstring[] _suggestions;
    private PopupWidget _popup;
    private ListWidget _popupList;
    /// suppresses the contentChange → updateSuggestions loop when setting text programmatically
    private bool _suppressPopup;

    this(string ID, dstring[] suggestions = []) {
        super(ID);
        _suggestions = suggestions;
        contentChange.connect(delegate(EditableContent src) {
            if (!_suppressPopup)
                updateSuggestions(src.text);
        });
    }

    /// Replace the full suggestion list.
    @property void suggestions(dstring[] s) {
        _suggestions = s;
    }

    alias text = EditLine.text;

    /// Suppress the suggestion popup when text is set programmatically.
    override @property Widget text(dstring newText) {
        _suppressPopup = true;
        scope(exit) _suppressPopup = false;
        return super.text(newText);
    }

    private void closePopup() {
        if (_popup !is null) {
            _popup.close();
            _popup = null;
            _popupList = null;
        }
    }

    private void showOrUpdatePopup(dstring[] filtered) {
        closePopup();

        _popupList = new ListWidget("ac_list");
        _popupList.adapter = new StringListAdapter(filtered);

        _popup = window.showPopup(_popupList, this,
            PopupAlign.Below | PopupAlign.FitAnchorSize);
        _popup.styleId = STYLE_POPUP_MENU;
        _popup.flags = PopupFlags.CloseOnClickOutside;
        _popup.popupClosed = delegate(PopupWidget _) {
            _popup = null;
            _popupList = null;
        };
        _popupList.itemClick = delegate(Widget _, int idx) {
            text = filtered[idx];
            closePopup();
            setFocus();
            return true;
        };
        // intentionally do NOT move focus to the list here —
        // the user should keep typing; Down arrow transfers focus explicitly
    }

    private void updateSuggestions(dstring input) {
        if (input.length == 0 || window is null) {
            closePopup();
            return;
        }
        auto lower = input.toLower;
        dstring[] filtered = _suggestions
            .filter!(s => s.toLower.startsWith(lower))
            .array;
        if (filtered.length == 0) {
            closePopup();
            return;
        }
        showOrUpdatePopup(filtered);
    }

    override bool onKeyEvent(KeyEvent event) {
        if (event.action == KeyAction.KeyDown && _popup !is null) {
            if (event.keyCode == KeyCode.DOWN) {
                // hand keyboard navigation off to the list widget
                _popupList.setFocus();
                return true;
            }
            if (event.keyCode == KeyCode.ESCAPE) {
                closePopup();
                return true;
            }
        }
        return super.onKeyEvent(event);
    }
}
