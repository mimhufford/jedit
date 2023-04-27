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
mode : enum { CANVAS; COMMAND; FRAGMENT; } = .CANVAS;
command : Line;

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

    set_scale(1);
    load_font();

    {
        f := array_add(*fragments);
        f.center = .{700, 500};
        fragment_add_line(f, "adjust_frag_index :: (delta: s64)");
        fragment_add_line(f, "{");
        fragment_add_line(f, "    active_fragment = (active_fragment + delta + fragments.count) % fragments.count;");
        fragment_add_line(f, "}");
    }
    {
        f := array_add(*fragments);
        f.center = .{550, 200};
        fragment_add_line(f, "colour :: Vector4.{1, 1, 1, 1};");
    }

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

    if key_pressed && key_code == .ESCAPE window_wants_to_quit = true;

    if key_pressed && ctrl_pressed && key_code == #char "+" adjust_scale(+1);
    if key_pressed && ctrl_pressed && key_code == #char "-" adjust_scale(-1);
    if key_pressed && ctrl_pressed && key_code == #char "0" set_scale(1);

    if key_pressed && ctrl_pressed && key_code == #char "S" save_as_jai_file();

    if key_pressed && ctrl_pressed && key_code == #char "N" new_fragment();

    if key_pressed && ctrl_pressed && key_code == #char " " mode = .COMMAND;

    if key_pressed && !ctrl_pressed && key_code == #char " "
    {
        if active_fragment >= 0
        {
            mode = .FRAGMENT;
        }
    }

    if key_pressed && key_code == .MOUSE_BUTTON_LEFT
    {
        active_fragment = -1;
        ui_offset_drag_start_pos = ui_offset;

        x, y := get_mouse_pointer_position(window, true);
        left_click_down_start_pos.x = xx x;
        left_click_down_start_pos.y = xx y;
        x = xx (x - ui_offset.x);
        y = xx (y - ui_offset.y);
        left_click_down = true;
        for fragments
        {
            if x < cast(int) it.bot_left.x continue;
            if x > cast(int) it.top_right.x continue;
            if y < cast(int) it.bot_left.y continue;
            if y > cast(int) it.top_right.y continue;
            active_fragment = it_index;
            active_fragment_click_offset.x = it.center.x - (x / ui_scale);
            active_fragment_click_offset.y = it.center.y - (y / ui_scale);
        }
    }

    if !key_pressed && key_code == .MOUSE_BUTTON_LEFT left_click_down = false;
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
            recalculate(*fragments[active_fragment]);
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
        command.count = 0;
        mode = .CANVAS;
    }
    else if key_pressed && key_code == .ENTER
    {
        command.count = 0;
        execute_command(xx command);
        mode = .CANVAS;
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
        mode = .CANVAS;
    }
    else if key_pressed && key_code == .ARROW_UP
    {
        frag := *fragments[active_fragment];
        if frag.line_index > 0 frag.line_index -= 1;
    }
    else if key_pressed && key_code == .ARROW_DOWN
    {
        frag := *fragments[active_fragment];
        if frag.line_index < frag.lines.count - 1 frag.line_index += 1;
    }
    else if key_pressed && key_code == .BACKSPACE
    {
        frag := *fragments[active_fragment];
        if frag.lines.count == 0 return;
        line := *frag.lines[frag.line_index];
        if line.count > 0 line.count -= 1;
        recalculate(frag);
    }
    else if key_pressed && key_code == .ENTER
    {
        frag := *fragments[active_fragment];
        frag.line_index += 1;
        fragment_add_line(frag, "");
    }
    else if type == .TEXT_INPUT && utf32 >= 32 && utf32 <= 126
    {
        frag := *fragments[active_fragment];
        line := *frag.lines[frag.line_index];
        array_add(line, cast(u8)utf32);
        recalculate(frag);
    }
}

new_fragment :: ()
{
    f := array_add(*fragments);
    f.center = .{100, 100};
    fragment_add_line(f, copy_string(tprint("frag% :: %;", fragments.count, fragments.count)));
}

save_as_jai_file :: ()
{
    sb : String_Builder;

    for frag: fragments
    {
        for line: frag.lines
        {
            append(*sb, to_string(line));
            append(*sb, "\n");
        }

        append(*sb, "\n");
    }

    contents := builder_to_string(*sb);
    contents.count -= 2; // remove the last two new lines

    write_entire_file("test.jai", contents);
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
    for * fragments recalculate(it);
}

Line :: [..]u8; // @TODO: support non-ascii

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
}

fragment_add_line :: (fragment: *Fragment, text: string)
{
    line : Line;
    for 0..text.count-1 array_add(*line, text[it]);
    array_add(*fragment.lines, line);
    recalculate(fragment);
}

recalculate :: (fragment: *Fragment)
{
    text_width := 0;
    for fragment.lines text_width = max(text_width, Simp.prepare_text(font, xx it));
    bg_half_width  := (text_width / 2.0) + font_width; // a char width padding on left and right
    bg_half_height := ((font_height * fragment.lines.count) / 2.0) + (font_height / 2.0); // half a char height padding on top and bottom
    bg_half_dim := Vector2.{xx bg_half_width, xx bg_half_height};
    fragment.bot_left  = ui_scale * fragment.center - bg_half_dim;
    fragment.top_right = ui_scale * fragment.center + bg_half_dim;
}

draw_one_frame :: ()
{
    Simp.clear_render_target(window_colour.x, window_colour.y, window_colour.z, window_colour.w);

    for frag, frag_index: fragments
    {
        bl := frag.bot_left;   bl += ui_offset;
        tr := frag.top_right;  tr += ui_offset;

        Simp.set_shader_for_color();

        if frag_index == active_fragment
        {
            // draw 1 pixel white border
            Simp.immediate_quad(bl.x-1, bl.y-1, tr.x+1, tr.y+1, .{1,1,1,1});
        }

        // draw fragment background
        Simp.immediate_quad(bl.x, bl.y, tr.x, tr.y, frag.colour);

        if frag_index == active_fragment && mode == .FRAGMENT
        {
            // highlight current line
            Simp.immediate_quad(bl.x, tr.y - (font_height * frag.line_index) - font_height / 2, tr.x, tr.y - (font_height * (frag.line_index + 1)) - font_height / 2, .{.3,.3,.3,1});
        }

        for line, line_index: frag.lines
        {
            text_x := frag.bot_left.x + font_width + ui_offset.x;
            text_y := frag.top_right.y - ((line_index + 1) * font_height) - font_height * 0.25 + ui_offset.y;
            Simp.draw_text(font, xx text_x, xx text_y, xx line);
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

#import "Math";
#import "File";
#import "Basic";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.
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