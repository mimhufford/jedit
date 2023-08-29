//// FRAGMENT 951 507 ////
main :: ()
{
    set_scale(1);
    load_font();
}
//// FRAGMENT 954 286 ////
adjust_frag_index :: (delta: s64)
{
    active_fragment = (active_fragment + delta + fragments.count) % fragments.count;
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