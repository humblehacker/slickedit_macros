#include "slick.sh"
#require "color.e"

defeventtab open_project_file_settings;
#define RGB(r,g,b) (((b)<<16)|((g)<<8)|(r))

// GLOBALS
int def_opf_max_show_matches    = 100;
int def_opf_show_horz_scrollbar = 1;
int def_opf_show_vert_scrollbar = 1;
int def_opf_max_weight          = 100;
int def_opf_foreground_min      = RGB(0xff,0xff,0xff);
int def_opf_foreground_max      = RGB(0x00,0x00,0x00);
int def_opf_background_min      = RGB(0x30,0xff,0xff);
int def_opf_background_max      = RGB(0xff,0xff,0xff);
int def_opf_file_first          = 1;

void opfs_ok.on_create()
{
   opfs_cap.p_text                 = def_opf_max_show_matches;
   opfs_file_first.p_value         = def_opf_file_first;
   opfs_path_first.p_value         = def_opf_file_first ? 0 : 1;
   opfs_show_horz.p_value          = def_opf_show_horz_scrollbar;
   opfs_show_vert.p_value          = def_opf_show_vert_scrollbar;
   opfs_foreground_min.p_backcolor = def_opf_foreground_min;
   opfs_foreground_max.p_backcolor = def_opf_foreground_max;
   opfs_background_min.p_backcolor = def_opf_background_min;
   opfs_background_max.p_backcolor = def_opf_background_max;
}

void opfs_ok.lbutton_up()
{
   def_opf_max_show_matches = (int)opfs_cap.p_text;
   def_opf_show_horz_scrollbar = opfs_show_horz.p_value;
   def_opf_show_vert_scrollbar = opfs_show_vert.p_value;
   p_active_form._delete_window();
}

void opfs_foreground_min.lbutton_up()
{
   int color = show_color_picker(p_backcolor);
   if (color != COMMAND_CANCELLED_RC) 
      p_backcolor = def_opf_foreground_min = color;
}

void opfs_foreground_max.lbutton_up()
{
   int color = show_color_picker(p_backcolor);
   if (color != COMMAND_CANCELLED_RC) 
      p_backcolor = def_opf_foreground_max = color;
}

void opfs_background_min.lbutton_up()
{
   int color = show_color_picker(p_backcolor);
   if (color != COMMAND_CANCELLED_RC) 
      p_backcolor = def_opf_background_min = color;
}

void opfs_background_max.lbutton_up()
{
   int color = show_color_picker(p_backcolor);
   if (color != COMMAND_CANCELLED_RC) 
      p_backcolor = def_opf_background_max = color;
}

void opfs_file_first.lbutton_up()
{
   def_opf_file_first = opfs_file_first.p_value;
}

_form open_project_file_settings {
   p_backcolor=0x80000005;
   p_border_style=BDS_DIALOG_BOX;
   p_caption='Open project file - Settings';
   p_clip_controls=false;
   p_forecolor=0x80000008;
   p_height=2982;
   p_width=7904;
   p_x=1053;
   p_y=1484;
   _frame opfs_opt_frame {
      p_backcolor=0x80000005;
      p_caption='Optimization';
      p_clip_controls=true;
      p_forecolor=0x80000008;
      p_height=1320;
      p_tab_index=1;
      p_width=4026;
      p_x=3783;
      p_y=56;
      _text_box opfs_cap {
         p_auto_size=true;
         p_backcolor=0x80000005;
         p_border_style=BDS_FIXED_SINGLE;
         p_completion=NONE_ARG;
         p_forecolor=0x80000008;
         p_height=252;
         p_tab_index=2;
         p_tab_stop=true;
         p_width=847;
         p_x=1892;
         p_y=913;
         p_eventtab2=_ul2_textbox;
      }
      _label opfs_cap_label {
         p_alignment=AL_LEFT;
         p_auto_size=false;
         p_backcolor=0x80000005;
         p_border_style=BDS_NONE;
         p_caption='Items display cap';
         p_forecolor=0x80000008;
         p_height=242;
         p_tab_index=3;
         p_width=1617;
         p_word_wrap=false;
         p_x=187;
         p_y=913;
      }
      _spin opfs_cap_spinner {
         p_auto_size=true;
         p_backcolor=0x8000000F;
         p_delay=100;
         p_forecolor=0x80000008;
         p_height=242;
         p_increment=1;
         p_max=32767;
         p_min=0;
         p_tab_index=8;
         p_width=176;
         p_x=2744;
         p_y=913;
         p_eventtab2=_ul2_spinb;
      }
      _label opfs_cap_text {
         p_alignment=AL_LEFT;
         p_auto_size=false;
         p_backcolor=0x80000005;
         p_border_style=BDS_NONE;
         p_caption='Highlighting a large number of items can take some time.  If you find the display lags too much, try decreasing the following value.';
         p_forecolor=0x80000008;
         p_height=550;
         p_tab_index=11;
         p_width=3542;
         p_word_wrap=true;
         p_x=187;
         p_y=253;
      }
   }
   _command_button opfs_ok {
      p_cancel=false;
      p_caption='OK';
      p_default=true;
      p_height=294;
      p_tab_index=9;
      p_tab_stop=true;
      p_width=836;
      p_x=5968;
      p_y=2576;
   }
   _command_button opfs_cancel {
      p_cancel=true;
      p_caption='Cancel';
      p_default=false;
      p_height=294;
      p_tab_index=10;
      p_tab_stop=true;
      p_width=781;
      p_x=6925;
      p_y=2576;
   }
   _frame opfs_scrollbar_frame {
      p_backcolor=0x80000005;
      p_caption='Show scrollbars';
      p_clip_controls=true;
      p_forecolor=0x80000008;
      p_height=869;
      p_tab_index=12;
      p_width=4026;
      p_x=3783;
      p_y=1442;
      _check_box opfs_show_horz {
         p_alignment=AL_LEFT;
         p_backcolor=0x80000005;
         p_caption='horizontal';
         p_forecolor=0x80000008;
         p_height=297;
         p_style=PSCH_AUTO2STATE;
         p_tab_index=8;
         p_tab_stop=true;
         p_value=0;
         p_width=1199;
         p_x=187;
         p_y=341;
      }
      _check_box opfs_show_vert {
         p_alignment=AL_LEFT;
         p_backcolor=0x80000005;
         p_caption='vertical';
         p_forecolor=0x80000008;
         p_height=297;
         p_style=PSCH_AUTO2STATE;
         p_tab_index=9;
         p_tab_stop=true;
         p_value=0;
         p_width=1430;
         p_x=1924;
         p_y=364;
      }
   }
   _frame opfs_color_frame {
      p_backcolor=0x80000005;
      p_caption='Display';
      p_clip_controls=true;
      p_forecolor=0x80000008;
      p_height=2814;
      p_tab_index=13;
      p_width=3601;
      p_x=117;
      p_y=56;
      _picture_box opfs_background_min {
         p_auto_size=true;
         p_backcolor=0x80000005;
         p_border_style=BDS_FIXED_SINGLE;
         p_clip_controls=false;
         p_forecolor=0x80000008;
         p_height=242;
         p_max_click=MC_SINGLE;
         p_Nofstates=1;
         p_picture='';
         p_stretch=false;
         p_style=PSPIC_AUTO_BUTTON;
         p_tab_index=1;
         p_value=0;
         p_width=352;
         p_x=1926;
         p_y=2365;
         p_eventtab2=_ul2_picture;
      }
      _picture_box opfs_foreground_max {
         p_auto_size=true;
         p_backcolor=0x80000005;
         p_border_style=BDS_FIXED_SINGLE;
         p_clip_controls=false;
         p_forecolor=0x80000008;
         p_height=269;
         p_max_click=MC_SINGLE;
         p_Nofstates=1;
         p_picture='';
         p_stretch=false;
         p_style=PSPIC_AUTO_BUTTON;
         p_tab_index=2;
         p_value=0;
         p_width=352;
         p_x=2885;
         p_y=1932;
         p_eventtab2=_ul2_picture;
      }
      _picture_box opfs_foreground_min {
         p_auto_size=true;
         p_backcolor=0x80000005;
         p_border_style=BDS_FIXED_SINGLE;
         p_clip_controls=false;
         p_forecolor=0x80000008;
         p_height=269;
         p_max_click=MC_SINGLE;
         p_Nofstates=1;
         p_picture='';
         p_stretch=false;
         p_style=PSPIC_AUTO_BUTTON;
         p_tab_index=2;
         p_value=0;
         p_width=352;
         p_x=1926;
         p_y=1932;
         p_eventtab2=_ul2_picture;
      }
      _label ctllabel1 {
         p_alignment=AL_LEFT;
         p_auto_size=false;
         p_backcolor=0x80000005;
         p_border_style=BDS_NONE;
         p_caption='Foreground';
         p_forecolor=0x80000008;
         p_height=242;
         p_tab_index=3;
         p_width=957;
         p_word_wrap=false;
         p_x=299;
         p_y=1945;
      }
      _label ctllabel2 {
         p_alignment=AL_LEFT;
         p_auto_size=false;
         p_backcolor=0x80000005;
         p_border_style=BDS_NONE;
         p_caption='Background';
         p_forecolor=0x80000008;
         p_height=242;
         p_tab_index=4;
         p_width=957;
         p_word_wrap=false;
         p_x=299;
         p_y=2365;
      }
      _label ctllabel4 {
         p_alignment=AL_CENTER;
         p_auto_size=false;
         p_backcolor=0x80000005;
         p_border_style=BDS_NONE;
         p_caption='min';
         p_forecolor=0x80000008;
         p_height=236;
         p_tab_index=5;
         p_width=357;
         p_word_wrap=false;
         p_x=1924;
         p_y=1596;
      }
      _picture_box opfs_background_max {
         p_auto_size=true;
         p_backcolor=0x80000005;
         p_border_style=BDS_FIXED_SINGLE;
         p_clip_controls=false;
         p_forecolor=0x80000008;
         p_height=242;
         p_max_click=MC_SINGLE;
         p_Nofstates=1;
         p_picture='';
         p_stretch=false;
         p_style=PSPIC_AUTO_BUTTON;
         p_tab_index=6;
         p_value=0;
         p_width=352;
         p_x=2885;
         p_y=2365;
         p_eventtab2=_ul2_picture;
      }
      _label ctllabel4 {
         p_alignment=AL_CENTER;
         p_auto_size=false;
         p_backcolor=0x80000005;
         p_border_style=BDS_NONE;
         p_caption='max';
         p_forecolor=0x80000008;
         p_height=236;
         p_tab_index=7;
         p_width=351;
         p_word_wrap=false;
         p_x=2886;
         p_y=1596;
      }
      _radio_button opfs_file_first {
         p_alignment=AL_LEFT;
         p_backcolor=0x80000005;
         p_caption='filename first (e.g. ''file.ext    path/to/the'')';
         p_forecolor=0x80000008;
         p_height=238;
         p_tab_index=8;
         p_tab_stop=true;
         p_value=0;
         p_width=3185;
         p_x=299;
         p_y=602;
      }
      _radio_button opfs_path_first {
         p_alignment=AL_LEFT;
         p_backcolor=0x80000005;
         p_caption='path first (e.g. ''path/to/the/file.ext'')';
         p_forecolor=0x80000008;
         p_height=238;
         p_tab_index=9;
         p_tab_stop=true;
         p_value=0;
         p_width=3185;
         p_x=299;
         p_y=966;
         p_eventtab=open_project_file_settings.opfs_file_first;
      }
      _label ctllabel5 {
         p_alignment=AL_LEFT;
         p_auto_size=false;
         p_backcolor=0x80000005;
         p_border_style=BDS_NONE;
         p_caption='Show entries as:';
         p_forecolor=0x80000008;
         p_height=252;
         p_tab_index=10;
         p_width=1378;
         p_word_wrap=false;
         p_x=187;
         p_y=294;
      }
      _label ctllabel6 {
         p_alignment=AL_LEFT;
         p_auto_size=false;
         p_backcolor=0x80000005;
         p_border_style=BDS_NONE;
         p_caption='Highlight colors';
         p_forecolor=0x80000008;
         p_height=308;
         p_tab_index=11;
         p_width=1373;
         p_word_wrap=false;
         p_x=187;
         p_y=1428;
      }
   }
}
