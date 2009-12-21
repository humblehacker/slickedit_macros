#include "slick.sh"

_form open_project_file {
   p_backcolor=0x80000005;
   p_border_style=BDS_SIZABLE;
   p_caption='Open Project File';
   p_clip_controls=false;
   p_forecolor=0x80000008;
   p_height=6741;
   p_width=11210;
   p_x=1078;
   p_y=1375;
   p_eventtab=open_project_file;
   _label opf_file_name {
      p_alignment=AL_LEFT;
      p_auto_size=false;
      p_backcolor=0x80000008;
      p_border_style=BDS_SUNKEN;
      p_caption='';
      p_font_name='Tahoma';
      p_forecolor=0x80000008;
      p_height=234;
      p_tab_index=2;
      p_width=11084;
      p_word_wrap=false;
      p_x=66;
      p_y=35;
   }
   _tree_view opf_files {
      p_after_pic_indent_x=50;
      p_backcolor=0x80000005;
      p_border_style=BDS_FIXED_SINGLE;
      p_clip_controls=false;
      p_CheckListBox=false;
      p_CollapsePicture='_lbminus.bmp';
      p_ColorEntireLine=false;
      p_EditInPlace=false;
      p_delay=0;
      p_ExpandPicture='_lbplus.bmp';
      p_font_name='Tahoma';
      p_forecolor=0x80000008;
      p_Gridlines=TREE_GRID_NONE;
      p_height=3175;
      p_LeafPicture='';
      p_LevelIndent=50;
      p_LineStyle=TREE_DOTTED_LINES;
      p_multi_select=MS_NONE;
      p_NeverColorCurrent=false;
      p_ShowRoot=false;
      p_AlwaysColorCurrent=false;
      p_SpaceY=40;
      p_scroll_bars=SB_VERTICAL;
      p_tab_index=1;
      p_tab_stop=true;
      p_width=11084;
      p_x=76;
      p_y=304;
      p_eventtab2=_ul2_tree;
   }
   _editor opf_files2 {
      p_auto_size=true;
      p_backcolor=0x80000005;
      p_border_style=BDS_FIXED_SINGLE;
      p_height=2882;
      p_scroll_bars=SB_BOTH;
      p_tab_index=3;
      p_tab_stop=true;
      p_width=11110;
      p_x=55;
      p_y=3542;
      p_eventtab2=_ul2_editwin;
   }
   _label opf_status1 {
      p_alignment=AL_LEFT;
      p_auto_size=false;
      p_backcolor=0x80000008;
      p_border_style=BDS_NONE;
      p_caption='';
      p_font_name='Tahoma';
      p_forecolor=0x80000008;
      p_height=234;
      p_tab_index=2;
      p_width=5542;
      p_word_wrap=false;
      p_x=66;
      p_y=6424;
   }
   _label opf_status2 {
      p_alignment=AL_LEFT;
      p_auto_size=false;
      p_backcolor=0x80000008;
      p_border_style=BDS_NONE;
      p_caption='';
      p_font_name='Tahoma';
      p_forecolor=0x80000008;
      p_height=234;
      p_tab_index=2;
      p_width=5542;
      p_word_wrap=false;
      p_x=5608;
      p_y=6424;
   }
}
