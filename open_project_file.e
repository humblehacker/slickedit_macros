//
// Copyright (c) 2009      David Whetstone
// Copyright (c) 2003-2008 Alexander Sandler
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "slick.sh"
#import "editfont.e"
#import "progress.e"
#import "weightedentry.e"
#require "open_project_file_settings.e"

#pragma option( strict, on )

defeventtab open_project_file;
_control opf_files;

const DELETE_TO_END_OF_BUFFER = -2; // used in _editor._delete_text()

static _str s_files[];
static WeightedEntry s_entries[];

static int  s_timer_handle  =  0;
static int  s_marker_type   = -1;
static int  s_max_red_index = -1;
static int  s_red_color[];

definit()
{
   s_files         = null;
   s_entries       = null;
   s_marker_type   = _MarkerTypeAlloc();
   s_max_red_index = 50;

   int i, min_red = 55;
   for (i = 0; i < s_max_red_index; ++i)
   {
      int redlevel = (i+1)*(256-min_red)/s_max_red_index-1+min_red;
      dsay("redlevel["i"] = "redlevel);
      s_red_color[i] = _AllocColor();
      _default_color( s_red_color[i], 0xffffff, _rgb(redlevel,0,0), F_BOLD );
   }
}

// called when current project is modified
void _prjupdate_opf()
{
   unload_entries();
}

void _workspace_opened_opf()
{
   unload_entries();
}

void _wkspace_close_opf()
{
   unload_entries();
}

static int red_level(int level)
{
   if (level > s_max_red_index)
      level = s_max_red_index;
   return s_red_color[level];
}

static void close_form()
{
   p_active_form._delete_window();
}

static void unload_entries()
{
   s_files = null;
   s_entries = null;
}

static int check_for_project()
{
   _str ext = _project_get_filename();

   if (strcmp( substr( ext, length( ext ) - 2, 3 ), "vpe" ) == 0)
   {
      return 0;
   }
   else
   {
      return 1;
   }
}

static int preparse_project( int *id )
{
   int status = 0;

   *id = _xmlcfg_open( _project_get_filename(), &status );

   return status;
}

static int project_find_files( int xml, int index )
{
   if (index < 0)
   {
      return 0;
   }

   if (_xmlcfg_get_name( xml, index ) == "Files")
   {
      return index;
   }

   int temp = project_find_files( xml, _xmlcfg_get_first_child( xml, index ) );
   if (temp != 0)
   {
      return temp;
   }

   temp = project_find_files( xml, _xmlcfg_get_next_sibling( xml, index ) );
   if (temp != 0)
   {
      return temp;
   }

   return 0;
}

static void parse_project( int xml, int index, _str basic_name )
{
   if (index < 0)
      return;

   int child;
   _str name;
   int idx = index;
   int idx2;

   do
   {
      if ((_xmlcfg_get_name( xml, idx ) == "F") && (_xmlcfg_get_attribute( xml, idx, "N", "" ) != ""))
      {
         name = _xmlcfg_get_attribute( xml, idx, "N", "" );
         s_files[s_files._length()] = name;
      }

      child = _xmlcfg_get_first_child( xml, idx );
      if (child >= 0)
         parse_project( xml, child, "" );

      idx = _xmlcfg_get_next_sibling( xml, idx );
   } while (idx >= 0);
}

static void forget_project( int tree )
{
   _xmlcfg_close( tree );
}

static _str get_current_line()
{
   select_line();
   filter_init();
   _str name;
   filter_get_string( name );
   _deselect();
   return name;
}

static _str regex_chars = "^$.+*?{}[]()\\|";

static _str make_regex( _str pattern )
{
   if (pattern == '')
      return ".*";

   _str ch, regex = "";
   int i, last = length(pattern);
   for (i = 1; i <= last; ++i)
   {
      ch = substr(pattern, i, 1);
      // escape regex characters
      if (pos( ch, regex_chars ) != 0) regex :+= "\\";
      regex :+= ch;
      if (i < last) regex :+= ".*";
   }
   return lowcase(regex);
}

static void highlight_text(int offset, int len, int color)
{
   int marker = _StreamMarkerAdd(opf_files, offset, len, false, 0, s_marker_type, '');
   _StreamMarkerSetTextColor( marker, color );
}

static void add_weighted_entry(WeightedEntry &entry, int &offset)
{
   // add the text
   _str text = *entry.m_text"\n";
   opf_files._insert_text(text);

   // mark the text
   if (entry.m_total_weight)
   {
      int i, last = entry.m_text->_length();
      for (i = 1; i <= last; ++i)
      {
         if (entry.m_char_weight[i])
            highlight_text(offset+i-1, 1, red_level(entry.m_char_weight[i]));
      }
   }

   // bump the offset
   offset += text._length();
}

static void opf_update_files(_str pattern)
{
   // clear list edit control
   opf_files._delete_text(DELETE_TO_END_OF_BUFFER);

   // build list of WeightedEntrys
   WeightedEntry *entries[] = null;
   WeightedEntry *entry;

   int idx, last = s_entries._length();
   for (idx = 0; idx < last; ++idx)
   {
      entry = &s_entries[idx];
      entry->weight_match(pattern);
      if (entry->m_total_weight > 0 || pattern._length()==0)
         entries[entries._length()] = entry;
   }

   // sort list by weight
   if (!pattern._length()==0)
      bucketsort(entries);

   // add entries to list edit control
   boolean capped = false;
   int offset = 0, count = 0;
   foreach (entry in entries)
   {
      if (entry->m_total_weight || pattern._length()==0)
         add_weighted_entry(*entry, offset);
      if (++count > def_opf_max_show_matches && pattern._length())
      {
         capped = true;
         break;
      }
   }

   // update status
   opf_status2.p_caption = entries._length() " of " s_files._length() " matched"(capped?" (capped at "def_opf_max_show_matches")":"");

   // refresh display
   opf_files.top();
   opf_files.refresh();
}

void open_project_file.on_load()
{
   opf_files._set_focus();
}

void opf_file_name.on_create()
{
   setEditFont( opf_file_name, CFG_DIALOG );
}

void opf_settings.on_create()
{
   _str dir = get_env("SLICKEDITCONFIGVERSION");
   _str filename = dir"gear.bmp";
   int index = _update_picture(-1, bitmap_path_search(filename));
   if (index < 0)
   {
      if (index == FILE_NOT_FOUND_RC)
      {
         _message_box("Picture "filename" was not found");
      }
      else
      {
         _message_box("Error loading picture "filename"\n\n"get_message(index));
      }
      return;
   }
   p_picture=index;
   p_message="Launches configuration dialog";
   p_style=PSPIC_FLAT_BUTTON;
}

static void update_scrollbars()
{
   if (def_opf_show_horz_scrollbar)
   {
      if (def_opf_show_vert_scrollbar)
         opf_files.p_scroll_bars = SB_BOTH;
      else
         opf_files.p_scroll_bars = SB_HORIZONTAL;
   }
   else if (def_opf_show_vert_scrollbar)
      opf_files.p_scroll_bars = SB_VERTICAL;
   else
      opf_files.p_scroll_bars = SB_NONE;
}

void opf_files.on_create()
{
   p_line_numbers_len = 0;
   p_KeepPictureGutter = false;
   p_readonly_mode = true;
   update_scrollbars();

   foreach (auto file in s_files)
   {
      opf_files._insert_text(file"\n");
   }
   opf_status2.p_caption = "0 of " s_files._length() " matched";
   opf_files.top();
   opf_files.refresh();
}

void open_project_file.on_resize()
{
   /*
                                        +-- opf_settings
                                        |
                                        v
          +---------------------------+---+
          |         opf_file_name     |   |   } fixed height
          +---------------------------+---+
          |                               |   \
          |                               |    |
          |           opf_files           |    |  variable height
          |                               |    |
          |                               |   /
          +---------------+---------------+
          |  opf_status1  |  opf_status2  |   } fixed height
          +---------------+---------------+

           \_____________/ \_____________/
              1/2 width       1/2 width
   */

   int clientwidth  = p_active_form.p_width;
   int clientheight = p_active_form.p_height;
   int hpad         = opf_file_name.p_x;
   int vpad         = opf_file_name.p_y;
   int fnpad        = 20; // Since the right inner border of a
   // sunken field is more pronounced, we align to this instead of
   // the outer border. Hence, the extra 20 units.

   // Calculate horizontal dimensions
   opf_files.p_width     = clientwidth - 2*hpad;
   opf_file_name.p_width = opf_files.p_width - opf_settings.p_width - hpad;
   opf_settings.p_x      = opf_file_name.p_x + opf_file_name.p_width + hpad;
   opf_status1.p_x       = opf_files.p_x;
   opf_status1.p_width   = (opf_files.p_width/2) - hpad;
   opf_status2.p_width   = opf_files.p_width - opf_status1.p_width;
   opf_status2.p_x       = opf_status1.p_x + opf_status1.p_width;

   // Calculate vertical dimensions
   opf_settings.p_y      = ((opf_file_name.p_height + 2*vpad) - opf_settings.p_height)/2;
   opf_files.p_height    = clientheight -
                           (4*vpad + opf_file_name.p_height + opf_status1.p_height);
   opf_files.p_y         = opf_file_name.p_y + opf_file_name.p_height + vpad;
   opf_status1.p_y       = opf_files.p_y + opf_files.p_height + vpad;
   opf_status2.p_y       = opf_status1.p_y;

   // Since opf_files.p_height will always be an even multiple of its line height,
   // the form may have extra blank space below the bottom-most controls.
   // Here we eliminate that extra space.
   p_active_form.p_height = opf_status1.p_y + opf_status1.p_height + vpad;
}

void opf_settings.lbutton_up()
{
   show("-modal open_project_file_settings");
   update_scrollbars();
}

void opf_files.'ENTER'()
{
   _str name = opf_files.get_current_line();

   // If after stripping path filename remains the same, we should append
   // project directory to filename as the name is relative to project path.
   // Otherwise we should use the name as is.
   if ((strip_filename( name, "D" ) == name) || (substr( name, 1, 1 ) :== "."))
   {
      _str proj = _project_get_filename();
      proj = strip_filename( proj, "N" );
      name = proj :+ name;
   }

   // quote name if it includes spaces
   if (pos( " ", name, 1, 'U' ) != 0)
      name = "\""name"\"";

   typeless form = p_active_form;
   e( name );
   form._delete_window();
}

void open_project_file.'ESC'()
{
   close_form();
}

void opf_timer_cb( int win_id )
{
   int cur_window;

   _kill_timer( s_timer_handle );

   cur_window = p_window_id;
   p_window_id = win_id;

// profile("on");
   opf_update_files( opf_file_name.p_caption );
// profile("view");

   p_window_id = cur_window;
}

void open_project_file.'BACKSPACE'()
{
   opf_file_name.p_caption = substr( opf_file_name.p_caption, 1, length( opf_file_name.p_caption ) - 1 );
   _kill_timer( s_timer_handle );
   s_timer_handle = _set_timer( 50, opf_timer_cb, p_active_form.p_window_id );
}

void opf_on_key()
{
   key := event2name( last_event( null, true ) );
   opf_file_name.p_caption = opf_file_name.p_caption""key;
   _kill_timer( s_timer_handle );
   s_timer_handle = _set_timer( 50, opf_timer_cb, p_active_form.p_window_id );
}

def  'a'-'z'      = opf_on_key;
def  'A'-'Z'      = opf_on_key;
def  '0'-'9'      = opf_on_key;
def  '_'          = opf_on_key;
def  '.'          = opf_on_key;
def  ' '          = opf_on_key;
def  '/'          = opf_on_key;
def  '\'          = opf_on_key;

_command void _open_project_file() name_info( ',' VSARG2_MACRO )
{
   // Checking if we have opened project...
   if (check_for_project() == 0)
   {
      _message_box( "Please open project first..." );
      return;
   }

   if (s_files._isempty())
   {
      _assert(s_entries._isempty());
      int xml_id = 0;
      int no_files = 0;

      if (preparse_project( &xml_id ))
      {
         _message_box( "Failed to load project file..." );
         return;
      }

      no_files = project_find_files( xml_id, 0 );
      s_files = null;
      s_entries = null;
      parse_project( xml_id, no_files, "" );
      s_files._sort('F');
      {
         WeightedEntry *entry;
         int i, last = s_files._length();
         Progress p("Calculating intrinsic weights", last);
         for (i = 0; i < last; ++i)
         {
            entry = &s_entries[s_entries._length()];
            // SlickC bug: I get 'invalid object' error on the following
            // set_text() call unless I set m_text beforehand.
            entry->m_text = &s_files[i];
            entry->set_text(&s_files[i]);
            entry->calc_intrinsic_weights();
            p.update(*entry->m_text, i);
         }
         forget_project( xml_id );
      }
   }

   _assert(!s_entries._isempty());
   _assert(!s_files._isempty());

   show( "-mdi -xy open_project_file" );
}

_form open_project_file {
   p_backcolor=0x80000005;
   p_border_style=BDS_SIZABLE;
   p_caption='Open Project File';
   p_clip_controls=false;
   p_forecolor=0x80000008;
   p_height=6369;
   p_width=8690;
   p_x=3674;
   p_y=1441;
   p_eventtab=open_project_file;
   _label opf_file_name {
      p_alignment=AL_LEFT;
      p_auto_size=false;
      p_backcolor=0x80000008;
      p_border_style=BDS_SUNKEN;
      p_caption='';
      p_font_name='Tahoma';
      p_forecolor=0x80000008;
      p_height=229;
      p_tab_index=2;
      p_width=8272;
      p_word_wrap=false;
      p_x=66;
      p_y=35;
   }
   _image opf_settings {
      p_auto_size=true;
      p_backcolor=0x80000005;
      p_border_style=BDS_NONE;
      p_forecolor=0x80000008;
      p_height=297;
      p_max_click=MC_SINGLE;
      p_Nofstates=1;
//    p_picture='gear.bmp';
      p_stretch=false;
      p_style=PSPIC_BUTTON;
      p_tab_index=1;
      p_value=0;
      p_width=297;
      p_x=1859;
      p_y=1562;
      p_eventtab2=_ul2_imageb;
   }
   _editor opf_files {
      p_auto_size=true;
      p_backcolor=0x80000005;
      p_border_style=BDS_FIXED_SINGLE;
      p_height=5698;
      p_scroll_bars=SB_BOTH;
      p_tab_index=3;
      p_tab_stop=true;
      p_width=8580;
      p_x=55;
      p_y=297;
      p_eventtab2=_ul2_editwin;
   }
   _label opf_status1 {
      p_alignment=AL_LEFT;
      p_auto_size=false;
      p_backcolor=0x80000008;
      p_border_style=BDS_SUNKEN;
      p_caption='';
      p_font_name='Tahoma';
      p_forecolor=0x80000008;
      p_height=231;
      p_tab_index=2;
      p_width=4554;
      p_word_wrap=false;
      p_x=55;
      p_y=6061;
   }
   _label opf_status2 {
      p_alignment=AL_LEFT;
      p_auto_size=false;
      p_backcolor=0x80000008;
      p_border_style=BDS_SUNKEN;
      p_caption='';
      p_font_name='Tahoma';
      p_forecolor=0x80000008;
      p_height=231;
      p_tab_index=2;
      p_width=4015;
      p_word_wrap=false;
      p_x=4620;
      p_y=6061;
   }
}


