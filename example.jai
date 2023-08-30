//// FRAGMENT 951 507 ////
main :: ()
{
    set_scale(1);
    load_font();
}
//// FRAGMENT 490 275 ////
Fragment_Type :: enum
{
    .UNKNOWN;
    .PROCEDURE;
    .STRUCT;
    .ENUM;
}
//// FRAGMENT 1393 525 ////
set_ui_offset :: (x: float, y: float)
{
    ui_offset.x = x;
    ui_offset.y = y;
}
//// FRAGMENT 460 516 ////
adjust_scale :: (delta: s64)
{
    if delta < 0 && ui_scale <= 0.3 return;
    if delta > 0 && ui_scale >= 10  return;
    if delta > 0 set_scale(ui_scale / 0.95);
    if delta < 0 set_scale(ui_scale * 0.95);
}
//// FRAGMENT 631 740 ////
set_scale :: (new_scale: float)
{
    ui_scale = new_scale;
    load_font();
}
//// FRAGMENT 1269 731 ////
load_font :: ()
{
    // load font at current scale
}
//// FRAGMENT 928 269 ////
Colour :: struct
{
    r: float;
    g: float;
    b: float;
}
//// FRAGMENT 1359 310 ////
WHITE   :: Colour.{1, 1, 1};
BLACK   :: Colour.{0, 0, 0};
ORANGE  :: Colour.{1, 1, 0};
MAGENTA :: Colour.{1, 0, 1};