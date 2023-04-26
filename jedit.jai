window : Window_Type;
window_width  := 1600;
window_height := 900;
window_colour := Vector4.{.1, .1, .1, 1};
ui_scale := 1.0;
left_click_down := false;
font : *Simp.Dynamic_Font;
font_default_height :: 20;
font_height := 0; // set programmatically when changing scale
font_width  := 0; // set programmatically when changing scale
active_fragment_click_offset : Vector2; // used when dragging a fragment around to avoid snapping to its center
active_fragment := -1;
fragments : [..]Fragment;

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
        add_text(f, "adjust_frag_index :: (delta: s64)");
        add_text(f, "{");
        add_text(f, "    active_fragment = (active_fragment + delta + fragments.count) % fragments.count;");
        add_text(f, "}");
    }
    {
        f := array_add(*fragments);
        f.center = .{550, 200};
        add_text(f, "colour :: Vector4.{1, 1, 1, 1};");
    }

    quit := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes()
        {
            Simp.update_window(it.window);

            if it.window != window continue;
            if it.width == window_width && it.height == window_height continue;

            window_width  = it.width;
            window_height = it.height;
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE quit = true;
                
                if it.key_pressed && it.ctrl_pressed && it.key_code == #char "+" adjust_scale(+1);
                if it.key_pressed && it.ctrl_pressed && it.key_code == #char "-" adjust_scale(-1);
                if it.key_pressed && it.ctrl_pressed && it.key_code == #char "0" set_scale(1);

                if it.key_pressed && it.ctrl_pressed && it.key_code == #char "S" save_as_jai_file();

                if it.key_pressed && it.key_code == .MOUSE_BUTTON_LEFT
                {
                    active_fragment = -1;

                    x, y := get_mouse_pointer_position(window, true);
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
                if !it.key_pressed && it.key_code == .MOUSE_BUTTON_LEFT left_click_down = false;
            }
        }

        if left_click_down && active_fragment >= 0
        {
            x, y := get_mouse_pointer_position(window, true);
            fragments[active_fragment].center.x = active_fragment_click_offset.x + x / ui_scale;
            fragments[active_fragment].center.y = active_fragment_click_offset.y + y / ui_scale;
            recalculate(*fragments[active_fragment]);
        }

        draw_one_frame();
        sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

save_as_jai_file :: ()
{
    sb : String_Builder;

    for frag: fragments
    {
        for line: frag.text
        {
            append(*sb, line);
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

adjust_scale :: (delta: s64)
{
    if ui_scale <= 0.1 return;
    if delta > 0 set_scale(ui_scale / 0.95);
    if delta < 0 set_scale(ui_scale * 0.95);
}

set_scale :: (new_scale: float)
{
    ui_scale = new_scale;
    load_font();
    for * fragments recalculate(it);
}

Fragment :: struct
{
    text   : [..]string;
    center : Vector2;
    colour := Vector4.{.2, .2, .2, 1};

    // The following variables are calculated and cached based on changes to text and center
    bot_left    : Vector2;
    top_right   : Vector2;
}

add_text :: (fragment: *Fragment, text: string)
{
    array_add(*fragment.text, text);
    recalculate(fragment);
}

recalculate :: (fragment: *Fragment)
{
    text_width := 0;
    for fragment.text text_width = max(text_width, Simp.prepare_text(font, it));
    bg_half_width  := (text_width / 2.0) + font_width; // a char width padding on left and right
    bg_half_height := ((font_height * fragment.text.count) / 2.0) + (font_height / 2.0); // half a char height padding on top and bottom
    bg_half_dim := Vector2.{xx bg_half_width, xx bg_half_height};
    fragment.bot_left  = ui_scale * fragment.center - bg_half_dim;
    fragment.top_right = ui_scale * fragment.center + bg_half_dim;
}

draw_one_frame :: () {
    Simp.clear_render_target(window_colour.x, window_colour.y, window_colour.z, window_colour.w);
    Simp.set_shader_for_color();

    // @TODO: why does this need doing in 2 passes?
    for frag, frag_index: fragments
    {
        if frag_index == active_fragment
        {
            Simp.immediate_quad(frag.bot_left.x-1, frag.bot_left.y-1, frag.top_right.x+1, frag.top_right.y+1, .{1,1,1,1});
        }
        Simp.immediate_quad(frag.bot_left.x, frag.bot_left.y, frag.top_right.x, frag.top_right.y, frag.colour);
    }
    for frag: fragments
    {
        for text, line: frag.text
        {
            text_x := frag.bot_left.x + font_width;
            text_y := frag.top_right.y - ((line + 1) * font_height) - font_height * 0.25;
            Simp.draw_text(font, xx text_x, xx text_y, text);
        }
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
        disable_runtime_console();
    }
}