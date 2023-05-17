window : Window_Type;
window_width  := 1600;
window_height := 900;
window_colour := Vector4.{.1, .1, .1, 1};
window_wants_to_quit := false;

ui_scale := 1.0;
ui_offset : Vector2;
ui_offset_drag_start_pos : Vector2;
left_click_down := false;
left_click_down_start_pos : Vector2;
font : *Simp.Dynamic_Font;
font_default_height :: 20;
font_height := 0; // set programmatically when changing scale
font_width  := 0; // set programmatically when changing scale
active_fragment_click_offset : Vector2; // used when dragging a fragment around to avoid snapping to its center
active_fragment := -1;
fragments : [..]Fragment;
mode := Mode.CANVAS;
next_mode := Mode.CANVAS;
command : Line;

Mode :: enum { CANVAS; COMMAND; FRAGMENT; };

main :: ()
{
    #if OS == .WINDOWS
    {
        #import "Windows";
        SetProcessDPIAware();
        timeBeginPeriod(1);
    }

    window = create_window(window_width, window_height, "Jai Editor", background_color_rgb = <<(cast(*[3]float)*window_colour.component));
    window_width, window_height = Simp.get_render_dimensions(window);

    Simp.set_render_target(window);

    maximise_window();

    set_scale(1);
    load_font();

    load_file("example.jai");

    while !window_wants_to_quit
    {
        Input.update_window_events();
        handle_window_resize();

        for Input.events_this_frame
        {
            if it.type == .QUIT then window_wants_to_quit = true;

            if #complete mode ==
            {
                case .CANVAS;   handle_canvas_input(it);
                case .COMMAND;  handle_command_input(it);
                case .FRAGMENT; handle_fragment_input(it);
            }
        }

        update_canvas();

        draw_one_frame();

        mode = next_mode;

        sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

handle_window_resize :: ()
{
    for Input.get_window_resizes()
    {
        Simp.update_window(it.window);

        if it.window != window continue;
        if it.width == window_width && it.height == window_height continue;

        window_width  = it.width;
        window_height = it.height;
    }
}

handle_canvas_input :: (using event: Input.Event)
{
    if type != .KEYBOARD return;

    if       key_pressed && key_code == .ESCAPE                    window_wants_to_quit = true;
    else if  key_pressed &&  ctrl_pressed && key_code == #char "+" adjust_scale(+1);
    else if  key_pressed &&  ctrl_pressed && key_code == #char "-" adjust_scale(-1);
    else if  key_pressed &&  ctrl_pressed && key_code == #char "0" set_scale(1);
    else if  key_pressed &&  ctrl_pressed && key_code == #char "S" save_as_jai_file();
    else if  key_pressed &&  ctrl_pressed && key_code == #char "N" new_fragment();
    else if  key_pressed &&  ctrl_pressed && key_code == #char " " next_mode = .COMMAND;
    else if  key_pressed && !ctrl_pressed && key_code == #char " " switch_to_fragment_mode();
    else if  key_pressed && key_code == .MOUSE_BUTTON_LEFT         maybe_set_active_fragment();
    else if !key_pressed && key_code == .MOUSE_BUTTON_LEFT         left_click_down = false;
}

maybe_set_active_fragment :: ()
{
    active_fragment = -1;
    ui_offset_drag_start_pos = ui_offset;

    x, y := get_mouse_pointer_position(window, true);
    left_click_down_start_pos.x = xx x;
    left_click_down_start_pos.y = xx y;
    x = xx (x - ui_offset.x);
    y = xx (y - ui_offset.y);
    left_click_down = true;
    for * fragments
    {
        if x < cast(int) it.bot_left.x continue;
        if x > cast(int) it.top_right.x continue;
        if y < cast(int) it.bot_left.y continue;
        if y > cast(int) it.top_right.y continue;
        active_fragment = it_index;
        active_fragment_click_offset.x = it.center.x - (x / ui_scale);
        active_fragment_click_offset.y = it.center.y - (y / ui_scale);
        next_mode = .CANVAS;
        break;
    }
}

switch_to_fragment_mode :: ()
{
    if active_fragment < 0 return;

    next_mode = .FRAGMENT;
}

update_canvas :: ()
{
    if mode != .CANVAS return;

    if left_click_down
    {
        if active_fragment >= 0
        {
            x, y := get_mouse_pointer_position(window, true);
            x = xx (x - ui_offset.x);
            y = xx (y - ui_offset.y);
            fragments[active_fragment].center.x = active_fragment_click_offset.x + x / ui_scale;
            fragments[active_fragment].center.y = active_fragment_click_offset.y + y / ui_scale;
            recalculate(*fragments[active_fragment], do_tokenisation = false);
        }
        else
        {
            x, y := get_mouse_pointer_position(window, true);
            ui_offset.x = ui_offset_drag_start_pos.x + x - left_click_down_start_pos.x;
            ui_offset.y = ui_offset_drag_start_pos.y + y - left_click_down_start_pos.y;
        }
    }
}

handle_command_input :: (using event: Input.Event)
{
    if key_pressed && key_code == .ESCAPE
    {
        next_mode = .CANVAS;
        command.count = 0;
    }
    else if key_pressed && key_code == .ENTER
    {
        next_mode = .CANVAS;
        execute_command(xx command);
        command.count = 0;
    }
    else if key_pressed && key_code == .BACKSPACE
    {
        if command.count > 0 command.count -= 1;
    }
    else if type == .TEXT_INPUT && utf32 >= 32 && utf32 <= 126
    {
        // @HACK the shortcut for this is Ctrl+Space which means a leading space is instantly
        //       added to the command buffer. This hack avoids it, but definitely isn't ideal
        if utf32 == 32 && command.count == 0 return;

        array_add(*command, cast(u8)utf32);
    }
}

execute_command :: (command: string)
{
    to_lower_in_place(command);

    // @TODO hook these up using metaprogramming
    if command ==
    {
        case "reset scale";   set_scale(1);
        case "reset offset";  set_ui_offset(0, 0);
    }
}

handle_fragment_input :: (using event: Input.Event)
{
    if key_pressed && key_code == .ESCAPE
    {
        active_fragment = -1;
        next_mode = .CANVAS;
    }
    else if   alt_pressed && key_pressed && key_code == .ARROW_UP           move_line_up();
    else if   alt_pressed && key_pressed && key_code == .ARROW_DOWN         move_line_down();
    else if                  key_pressed && key_code == .HOME               jump_to_start_of_line();
    else if                  key_pressed && key_code == .END                jump_to_end_of_line();
    else if  ctrl_pressed && key_pressed && key_code == .ENTER              new_line_below();
    else if shift_pressed && key_pressed && key_code == .ENTER              new_line_above();
    else if                  key_pressed && key_code == .ENTER              split_line_at_cursor();
    else if                  key_pressed && key_code == .ARROW_UP           move_cursor_up();
    else if                  key_pressed && key_code == .ARROW_DOWN         move_cursor_down();
    else if  ctrl_pressed && key_pressed && key_code == .ARROW_LEFT         move_cursor_left_to_next_whitespace();
    else if                  key_pressed && key_code == .ARROW_LEFT         move_cursor_left();
    else if  ctrl_pressed && key_pressed && key_code == .ARROW_RIGHT        move_cursor_right_to_next_whitespace();
    else if                  key_pressed && key_code == .ARROW_RIGHT        move_cursor_right();
    else if                  key_pressed && key_code == .BACKSPACE          delete_character_before_cursor();
    else if                  key_pressed && key_code == .DELETE             delete_character_under_cursor();
    else if                  key_pressed && key_code == .TAB                insert_tab_as_spaces();
    else if  ctrl_pressed && key_pressed && key_code == #char "/"           toggle_line_comment();
    else if  ctrl_pressed && key_pressed && key_code == #char "X"           cut_line_to_clipboard();
    else if  ctrl_pressed && key_pressed && key_code == #char "C"           copy_line_to_clipboard();
    else if  ctrl_pressed && key_pressed && key_code == #char "V"           paste_from_clipboard_to_new_line_below();
    else if                  key_pressed && key_code == .MOUSE_BUTTON_LEFT  maybe_set_active_fragment();
    else if                 !key_pressed && key_code == .MOUSE_BUTTON_LEFT  left_click_down = false;
    else if type == .TEXT_INPUT
    {
        frag := *fragments[active_fragment];
        line := *frag.lines[frag.line_index];
        byte := codepoint_index_to_byte_index(frag);
        data := character_utf32_to_utf8(utf32);
        for 0..data.count-1 array_insert_at(line, data[it], byte+it);
        frag.col_index += 1;
        recalculate(frag);
    }
}

toggle_line_comment :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    line := *frag.lines[frag.line_index];

    if line.count >= 2 && line.data[0] == #char "/" && line.data[1] == #char "/"
    {
        // uncomment the line
        for 1..2 array_ordered_remove_by_index(line, 0);
        frag.col_index = max(frag.col_index - 2, 0);
        recalculate(frag);
    }
    else
    {
        // comment the line
        for 1..2 array_insert_at(line, #char "/", 0);
        frag.col_index = min(frag.col_index + 2, count_codepoints_in_line(line));
        recalculate(frag);
    }
}

cut_line_to_clipboard :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    line := *frag.lines[frag.line_index];
    os_clipboard_set_text(cast(string)(<<line));
    if frag.lines.count > 1
    {
        array_ordered_remove_by_index(*frag.lines, frag.line_index);
        frag.line_index = min(frag.line_index, frag.lines.count - 1);
    }
    else
    {
        line.count = 0;
        frag.col_index = 0;
    }
    recalculate(frag);
}

copy_line_to_clipboard :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    line := *frag.lines[frag.line_index];
    os_clipboard_set_text(cast(string)(<<line));
}

paste_from_clipboard_to_new_line_below :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    new_line_below();
    line := *frag.lines[frag.line_index];
    data := os_clipboard_get_text();
    for 0..data.count-1 array_add(line, data[it]);
    recalculate(frag);
}

new_line_above :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    frag.col_index = 0;
    fragment_insert_line(frag, "");
}

new_line_below :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    frag.line_index += 1;
    frag.col_index = 0;
    fragment_insert_line(frag, "");
}

insert_tab_as_spaces :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    line := *frag.lines[frag.line_index];
    for 1..4 array_insert_at(line, #char " ", frag.col_index);
    frag.col_index += 4;
    recalculate(frag);
}

move_cursor_up :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    if frag.line_index > 0 frag.line_index -= 1;
    line := *frag.lines[frag.line_index];
    frag.col_index = min(frag.col_index, count_codepoints_in_line(line));
}

move_cursor_down :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    frag.line_index = min(frag.lines.count - 1, frag.line_index + 1);
    line := *frag.lines[frag.line_index];
    frag.col_index = min(frag.col_index, count_codepoints_in_line(line));
}

move_cursor_left_to_next_whitespace :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    line := *frag.lines[frag.line_index];
    while true
    {
        if frag.col_index == 0 break;
        frag.col_index -= 1;
        if line.data[frag.col_index] == #char " " break;
    }
}

move_cursor_left :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    if frag.col_index > 0 frag.col_index -= 1;
}

move_cursor_right_to_next_whitespace :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    line := *frag.lines[frag.line_index];
    last := count_codepoints_in_line(line);
    while true
    {
        if frag.col_index == last break;
        frag.col_index += 1;
        if line.data[frag.col_index] == #char " " break;
    }
}

move_cursor_right :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    line := *frag.lines[frag.line_index];
    frag.col_index = min(frag.col_index + 1, count_codepoints_in_line(line));
}

delete_character_before_cursor :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    if frag.lines.count == 0 return;
    line := *frag.lines[frag.line_index];
    if frag.col_index == 0
    {
        if frag.line_index == 0 return;  // can't backspace at 0, 0
        
        // delete before first causing rest of line to be appended to the previous line
        prev_line := *frag.lines[frag.line_index - 1];
        frag.col_index = count_codepoints_in_line(prev_line);
        for 0..line.count-1 array_add(prev_line, (<<line)[it]);
        array_ordered_remove_by_index(*frag.lines, frag.line_index);
        frag.line_index -= 1;
    }
    else
    {
        // delete from inside a line
        frag.col_index = max(frag.col_index - 1, 0);
        byte_start, byte_count := codepoint_index_to_byte_index(frag);
        for 0..byte_count-1 array_ordered_remove_by_index(line, byte_start);
    }
    recalculate(frag);
}

delete_character_under_cursor :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    if frag.lines.count == 0 return;
    line := *frag.lines[frag.line_index];
    if frag.col_index == line.count && frag.line_index < frag.lines.count - 1
    {
        // delete from the end of a line and append the next line's contents
        next_line := *frag.lines[frag.line_index + 1];
        for 0..next_line.count-1 array_add(line, next_line.data[it]);
        array_ordered_remove_by_index(*frag.lines, frag.line_index + 1);
    }
    else if line.count > 0 && frag.col_index < line.count
    {
        // delete from inside a line
        byte_index, byte_count := codepoint_index_to_byte_index(frag);
        for 1..byte_count array_ordered_remove_by_index(line, byte_index);
    }
    recalculate(frag);
}

move_line_up :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    if frag.line_index == 0 return;
    Swap(*frag.lines[frag.line_index - 1], *frag.lines[frag.line_index]);
    frag.line_index -= 1;
    recalculate(frag);
}

move_line_down :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    if frag.line_index == frag.lines.count - 1 return;
    Swap(*frag.lines[frag.line_index + 1], *frag.lines[frag.line_index]);
    frag.line_index += 1;
    recalculate(frag);
}

jump_to_start_of_line ::()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    frag.col_index = 0;
}

jump_to_end_of_line :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    line := *frag.lines[frag.line_index];
    frag.col_index = count_codepoints_in_line(line);
}

split_line_at_cursor :: ()
{
    if active_fragment < 0 return;
    frag := *fragments[active_fragment];
    frag.line_index += 1;
    fragment_insert_line(frag, "");
    prev_line := *frag.lines[frag.line_index - 1];
    next_line := *frag.lines[frag.line_index];
    frag.line_index -= 1;
    byte_index := codepoint_index_to_byte_index(frag);
    frag.line_index += 1;
    for byte_index..prev_line.count-1 array_add(next_line, prev_line.data[it]);
    prev_line.count -= next_line.count;
    frag.col_index = 0;
    recalculate(frag);
}

UNFINISHED_search :: (search: string)
{
    for * frag, frag_index: fragments
    {
        for * line, line_index: frag.lines
        {
            col_index := find_index_from_left(cast(string)(<<line), search);

            if col_index >= 0
            {
                active_fragment = frag_index;
                frag.line_index = line_index;
                frag.col_index = col_index;
                next_mode = .FRAGMENT;
                break frag;
            }
        }
    }
}

new_fragment :: ()
{
    f := array_add(*fragments);
    f.center = .{100, 100};
    fragment_append_line(f, copy_string(tprint("frag% :: %;", fragments.count, fragments.count)));
}

save_as_jai_file :: ()
{
    sb : String_Builder;

    for frag: fragments
    {
        append(*sb, tprint("//// FRAGMENT % % ////\n", frag.center.x, frag.center.y));

        for line: frag.lines
        {
            append(*sb, to_string(line));
            append(*sb, "\n");
        }
    }

    contents := builder_to_string(*sb);
    contents.count -= 1; // remove the last extra new line

    write_entire_file("example.jai", contents);
}

adjust_frag_index :: (delta: s64)
{
    active_fragment = (active_fragment + delta + fragments.count) % fragments.count;
}

set_ui_offset :: (x: float, y: float)
{
    ui_offset.x = x;
    ui_offset.y = y;
}

adjust_scale :: (delta: s64)
{
    if delta < 0 && ui_scale <= 0.3 return;
    if delta > 0 && ui_scale >= 10  return;
    if delta > 0 set_scale(ui_scale / 0.95);
    if delta < 0 set_scale(ui_scale * 0.95);
}

set_scale :: (new_scale: float)
{
    ui_scale = new_scale;
    load_font();
    for * fragments recalculate(it, do_tokenisation = false);
}

Line :: [..]u8;

Fragment :: struct
{
    lines  : [..]Line;
    center : Vector2;
    colour := Vector4.{.2, .2, .2, 1};

    // Fragment edit mode state variables
    line_index := 0;
    col_index  := 0;

    // The following variables are calculated and cached based on changes to text and center
    bot_left    : Vector2;
    top_right   : Vector2;

    // Calculated and cached whenever text changes
    tokens : [..][..]Token;
}

count_codepoints_in_line :: (line: *Line) -> s64
{
    count := 0;
    index := 0;

    while index < line.count
    {
        index += 1 + trailingBytesForUTF8[line.data[index]];
        count += 1;
    }

    return count;
}

// @TODO: this can probably be rewritten just using trailingBytesForUTF8
codepoint_index_to_byte_index :: (fragment: *Fragment) -> s64, s64
{
    shallow_orig := fragment.lines[fragment.line_index];
    shallow_copy := fragment.lines[fragment.line_index];

    for 0..fragment.col_index-1
    {
        code, result := utf8_next_character(cast(*string)(*shallow_copy));
    }

    byte_index := shallow_copy.data - shallow_orig.data;
    byte_count := 1;

    if (shallow_copy.data - (shallow_orig.data + shallow_orig.count)) != 0
    {
        // the cursor is over a character (i.e. not right at the end of a line)
        // so we can safely look at it and add on how many extra bytes it has
        byte_count += trailingBytesForUTF8[shallow_copy[0]];
    }

    return byte_index, byte_count;
}

fragment_insert_line :: (fragment: *Fragment, text: string)
{
    line : Line;
    for 0..text.count-1 array_add(*line, text[it]);
    array_insert_at(*fragment.lines, line, fragment.line_index);
    recalculate(fragment);
}

fragment_append_line :: (fragment: *Fragment, text: string)
{
    line : Line;
    for 0..text.count-1 array_add(*line, text[it]);
    array_add(*fragment.lines, line);
    recalculate(fragment);
}

recalculate :: (fragment: *Fragment, do_tokenisation := true)
{
    text_width := 0;
    for fragment.lines text_width = max(text_width, Simp.prepare_text(font, xx it));
    bg_half_width  := (text_width / 2.0) + font_width; // a char width padding on left and right
    bg_half_height := ((font_height * fragment.lines.count) / 2.0) + (font_height / 2.0); // half a char height padding on top and bottom
    bg_half_dim := Vector2.{xx bg_half_width, xx bg_half_height};
    fragment.bot_left  = ui_scale * fragment.center - bg_half_dim;
    fragment.top_right = ui_scale * fragment.center + bg_half_dim;
    if do_tokenisation UNFINISHED_tokenise(fragment);
}

Token_Type :: enum
{
    NONE; // catch-all for tokens without a colour
    TYPE;
    NUMBER;
    STRING;
    KEYWORD;
    COMMENT;
    OPERATOR;
    IDENTIFIER;
}

Token :: struct
{
    type: Token_Type;
    value: string; // not owned, pointer into fragment lines
    index: s64;
}

UNFINISHED_tokenise :: (fragment: *Fragment)
{
    keywords :: string.["if", "else", "ifx", "then", "while", "for", "break", "continue", "return", "struct", "enum" ];
    types    :: string.["int", "float", "u8", "u16", "u32", "u64", "s8", "s16", "s32", "s64", "bool", "string" ];

    for * fragment.tokens array_reset(it);
    array_reset(*fragment.tokens);

    for line: fragment.lines
    {
        index := 0;
        tokens := array_add(*fragment.tokens);

        while true
        {
            if index >= line.count break;

            // Even though non-ascii characters aren't legal outside of string (I think...)
            // they need to be parsed as a single token so they don't get rendered seperately.
            // That's why the following includes the trailingBytesForUTF8 stuff.
            token := array_add(tokens);
            token.value.data = line.data + index;
            token.value.count = 1 + trailingBytesForUTF8[<<token.value.data];
            token.index = index;
            index += trailingBytesForUTF8[<<token.value.data];

            if is_letter_or_underscore(line[index])
            {
                index += 1;
                while index < line.count && (is_letter_or_underscore(line[index]) || is_number(line[index]))
                {
                    index += 1;
                    token.value.count += 1;
                }

                if array_find(keywords, token.value)   token.type = .KEYWORD;
                else if array_find(types, token.value) token.type = .TYPE;
                else                                   token.type = .IDENTIFIER;
            }
            else if is_number(line[index])
            {
                // TODO: this is very basic, doesn't handle 0b, 0x
                index += 1;
                while index < line.count && (is_number(line[index]) || line[index] == #char "_")
                {
                    index += 1;
                    token.value.count += 1;
                }

                token.type = .NUMBER;
            }
            else if line[index] == #char "\""
            {
                // TODO: this is very basic, doesn't handle escapes
                index += 1;
                while index < line.count && line[index] != #char "\""
                {
                    index += 1;
                    token.value.count += 1;
                }

                if index < line.count
                {
                    assert(line[index] == #char "\"");
                    index += 1;
                    token.value.count += 1;
                }

                token.type = .STRING;
            }
            else if line[index] == #char "/"
            {
                index += 1;

                // single line comments
                if index < line.count && line[index] == #char "/"
                {
                    index += 1;
                    token.value.count += 1;
                    token.type = .COMMENT;

                    while index < line.count
                    {
                        index += 1;
                        token.value.count += 1;
                    }
                }
            }
            else
            {
                index += 1;
            }
        }
    }

    is_letter_or_underscore :: (c: u8) -> bool
    {
        is_lower      := c >= #char "a" && c <= #char "z";
        is_upper      := c >= #char "A" && c <= #char "Z";
        is_underscore := c == #char "_";

        return is_lower || is_upper || is_underscore;
    }
    
    is_number :: (c: u8) -> bool
    {
        return c >= #char "0" && c <= #char "9";
    }
}

hex_to_vector4 :: (hex: s32) -> Vector4
{
    r := ((hex >> 24) & 0xFF) / 255.0;
    g := ((hex >> 16) & 0xFF) / 255.0;
    b := ((hex >>  8) & 0xFF) / 255.0;
    a := ((hex >>  0) & 0xFF) / 255.0;
    return .{r, g, b, a};
}

draw_one_frame :: ()
{
    Simp.clear_render_target(window_colour.x, window_colour.y, window_colour.z, window_colour.w);

    for frag, frag_index: fragments
    {
        bl := frag.bot_left;   bl += ui_offset;
        tr := frag.top_right;  tr += ui_offset;

        // skip rendering fragment if it's not within viewport
        if (tr.x <= 0) continue;
        if (tr.y <= 0) continue;
        if (bl.x >= cast(float)window_width) continue;
        if (bl.y >= cast(float)window_height) continue;

        Simp.set_shader_for_color();

        // draw 1 pixel border
        border_colour := Vector4.{0, 0, 0, 1};
        if frag_index == active_fragment border_colour = .{1, 1, 1, 1};
        Simp.immediate_quad(bl.x-1, bl.y-1, tr.x+1, tr.y+1, border_colour);

        // draw fragment background
        Simp.immediate_quad(bl.x, bl.y, tr.x, tr.y, frag.colour);

        if frag_index == active_fragment && mode == .FRAGMENT
        {
            // highlight cursor position
            left   := bl.x + (font_width * frag.col_index) + (font_width * 1);
            right  := bl.x + (font_width * frag.col_index) + (font_width * 2);
            top    := tr.y - (font_height * frag.line_index) - font_height / 2;
            bottom := tr.y - (font_height * (frag.line_index + 1)) - font_height / 2;
            colour := frag.colour + .{.2, .2, .2, 0};
            Simp.immediate_quad(left, top, right, bottom, colour);
        }

        for tokens, line_index: frag.tokens
        {
            text_x := frag.bot_left.x + font_width + ui_offset.x;
            text_y := frag.top_right.y - ((line_index + 1) * font_height) - font_height * 0.25 + ui_offset.y;

            for token: tokens
            {
               width := Simp.prepare_text(font, token.value);
               // @TODO: define nice colours, put them in a data structure, make them customisable
               colour := Vector4.{1, 1, 1, 1};
               if      token.type == .STRING  colour = hex_to_vector4(0xFEED6CFF);
               else if token.type == .NUMBER  colour = hex_to_vector4(0x9E6FFEFF);
               else if token.type == .TYPE    colour = hex_to_vector4(0x8CEDFFFF);
               else if token.type == .COMMENT colour = hex_to_vector4(0xCCCCC6FF);
               else if token.type == .KEYWORD colour = hex_to_vector4(0xFF5995FF);
               Simp.draw_prepared_text(font, xx text_x, xx text_y, colour);
               text_x += width;
            }
        }
    }

    if mode == .COMMAND
    {
        top_padding :: 100;
        tl := Vector2.{window_width * 0.5 - font_width * 25, xx (window_height - top_padding)};
        br := Vector2.{window_width * 0.5 + font_width * 25, xx (window_height - top_padding - font_height * 2)};

        Simp.set_shader_for_color();
        Simp.immediate_quad(tl.x-1, tl.y+1, br.x+1, br.y-1, .{1., 1., 1., 1});
        Simp.immediate_quad(tl.x  , tl.y  , br.x  , br.y  , .{.2, .2, .2, 1});

        Simp.draw_text(font, xx (tl.x + font_width), xx (tl.y - font_height * 1.25), xx command);
    }

    Simp.swap_buffers(window);
}

load_file :: (path: string)
{
    // @TEMP: simple source comment based system until proper jai parsing is implemented

    data, ok := read_entire_file(path);

    if !ok return;

    frag : *Fragment;

    lines := split(data, "\n");

    for file_line: lines
    {
        if starts_with(file_line, "//// FRAGMENT")
        {
            parts := split(file_line, " ");
            frag = array_add(*fragments);
            frag.center.x = parse_float(*parts[2]);
            frag.center.y = parse_float(*parts[3]);
        }
        else
        {
            line := array_add(*frag.lines);
            for 0..file_line.count-1 array_add(line, file_line[it]);
        }
    }

    for * fragments recalculate(it);
}

load_font :: ()
{
    // @LEAK: previously loaded font sizes are leaked

    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);
    font_height = xx (font_default_height * ui_scale);
    font = Simp.get_font_at_size(".", "SourceCodePro-Regular.ttf", font_height);
    font_width = Simp.prepare_text(font, "w");
    assert(font != null);
}

maximise_window :: ()
{
    #if OS == .WINDOWS
    {
        ShowWindow(window, SW_MAXIMIZE);
    }
}

#import "Math";
#import "File";
#import "Basic";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.
#import "Unicode";
#import "Clipboard";
#import "Window_Creation";
Input :: #import "Input";
Simp  :: #import "Simp";

#run {
    #if OS == .WINDOWS {
        #import "Windows_Resources";
        // @TODO: put behind a release flag
        // disable_runtime_console();
    }
}