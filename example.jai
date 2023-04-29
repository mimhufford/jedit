//// FRAGMENT 800 150 ////
adjust_frag_index :: (delta: s64)
{
    active_fragment = (active_fragment + delta + fragments.count) % fragments.count;
}
//// FRAGMENT 1200 500 ////
set_ui_offset :: (x: float, y: float)
{
    ui_offset.x = x;
    ui_offset.y = y;
}
//// FRAGMENT 500 600 ////
adjust_scale :: (delta: s64)
{
    if delta < 0 && ui_scale <= 0.3 return;
    if delta > 0 && ui_scale >= 10  return;
    if delta > 0 set_scale(ui_scale / 0.95);
    if delta < 0 set_scale(ui_scale * 0.95);
}