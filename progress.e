#include "slick.sh"
#import "dlgman.e"
#require "sc/lang/IControlID.e"

defeventtab wpf_progress;

_nocheck _control wpf_progress_bar;
_nocheck _control wpf_current_item;

class Progress : sc.lang.IControlID
{
   private int m_wid;
   private int m_max;
   private int m_prev_progress;
   private typeless m_disabled_wid_list;
   Progress(_str title="", int max=100)
   {
      m_wid = show("wpf_progress");
      // Disable all forms except this one
      m_disabled_wid_list = _enable_non_modal_forms(0, m_wid);
      m_wid.p_caption = title;
      m_wid.wpf_progress_bar.p_value = 0;
      m_max = max;
      m_prev_progress = 0;
   }
   ~Progress()
   {
      _enable_non_modal_forms(1, 0, m_disabled_wid_list);
      m_wid._delete_window(m_wid);
   }
   int getWindowID()
   {
      return m_wid;
   }
   void update(_str caption, int value)
   {
      int progress = (value+1)*100/m_max;
      if (progress > m_prev_progress)
      {
         m_wid.wpf_current_item.p_caption = caption;
         m_wid.wpf_progress_bar.p_value = progress;
         m_wid.refresh();
         m_prev_progress = progress;
      }
   }
};

_form wpf_progress {
   p_backcolor=0x80000005;
   p_border_style=BDS_DIALOG_BOX;
   p_caption='';
   p_clip_controls=false;
   p_forecolor=0x80000008;
   p_height=792;
   p_width=4961;
   p_x=2838;
   p_y=2761;
   _label wpf_current_item {
      p_alignment=AL_LEFT;
      p_auto_size=false;
      p_backcolor=0x80000005;
      p_border_style=BDS_NONE;
      p_caption='';
      p_forecolor=0x80000008;
      p_height=231;
      p_tab_index=2;
      p_width=4675;
      p_word_wrap=false;
      p_x=121;
      p_y=121;
   }
   _gauge wpf_progress_bar {
      p_backcolor=0x80000005;
      p_forecolor=0x80000008;
      p_height=187;
      p_max=100;
      p_min=0;
      p_style=PSGA_HORZ_WITH_PERCENT;
      p_tab_index=1;
      p_tab_stop=false;
      p_value=0;
      p_width=4675;
      p_x=121;
      p_y=418;
   }
}
