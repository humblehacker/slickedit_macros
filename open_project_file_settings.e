#include "slick.sh"

defeventtab open_project_file_settings;

// GLOBALS
int def_opf_max_show_matches = 100;
int def_opf_show_horz_scrollbar = 1;
int def_opf_show_vert_scrollbar = 1;

void opfs_cap.on_create()
{
   p_text = def_opf_max_show_matches;
}

void opfs_ok.lbutton_up()
{
   def_opf_max_show_matches = (int)opfs_cap.p_text;
   def_opf_show_horz_scrollbar = opfs_show_horz.p_value;
   def_opf_show_vert_scrollbar = opfs_show_vert.p_value;
   p_active_form._delete_window();
}

void opfs_show_horz.on_create()
{
   p_value = def_opf_show_horz_scrollbar;
}

void opfs_show_vert.on_create()
{
   p_value = def_opf_show_vert_scrollbar;
}

_form open_project_file_settings {
   p_backcolor=0x80000005;
   p_border_style=BDS_DIALOG_BOX;
   p_caption='Open project file - Settings';
   p_clip_controls=false;
   p_forecolor=0x80000008;
   p_height=2816;
   p_width=4147;
   p_x=3762;
   p_y=3971;
   _frame opfs_opt_frame {
      p_backcolor=0x80000005;
      p_caption='Optimization';
      p_clip_controls=true;
      p_forecolor=0x80000008;
      p_height=1320;
      p_tab_index=1;
      p_width=4026;
      p_x=55;
      p_y=55;
      _text_box opfs_cap {
         p_auto_size=true;
         p_backcolor=0x80000005;
         p_border_style=BDS_FIXED_SINGLE;
         p_completion=NONE_ARG;
         p_forecolor=0x80000008;
         p_height=242;
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
         p_x=209;
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
      p_caption='Ok';
      p_default=true;
      p_height=294;
      p_tab_index=9;
      p_tab_stop=true;
      p_width=836;
      p_x=2211;
      p_y=2401;
   }
   _command_button opfs_cancel {
      p_cancel=true;
      p_caption='Cancel';
      p_default=false;
      p_height=294;
      p_tab_index=10;
      p_tab_stop=true;
      p_width=781;
      p_x=3168;
      p_y=2401;
   }
   _frame opf_scrollbar_frame {
      p_backcolor=0x80000005;
      p_caption='Show scrollbars';
      p_clip_controls=true;
      p_forecolor=0x80000008;
      p_height=869;
      p_tab_index=12;
      p_width=4026;
      p_x=55;
      p_y=1408;
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
         p_x=209;
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
         p_x=1914;
         p_y=341;
      }
   }
}
