//
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
// 05/11/2008 - Version 1.0.9
// This version adds _TreeRefresh() call at the end of opf_update_tree(). This fixes
// a problem with trees in SE that are not automatically updated after a change has
// been made.
//

#include "slick.sh"
#include "form_open_project_file.e"
#import "editfont.e"

#pragma option( strict, on )

defeventtab open_project_file;

#define OPF_NO_MATCH      0
#define OPF_EXACT_MATCH   1
#define OPF_PATTERN_MATCH 2
#define DELETE_TO_END_OF_BUFFER -2 // used in _editor._delete_text()

static int  opf_filt_font       = CFG_DIALOG;
static int  opf_timer_handle    = 0;
static int  s_markerType        = -1;
static int  s_exactMatchColor   = -1;
static int  s_partialMatchColor = -1;
static _str s_files[];

definit()
{
   s_markerType        = _MarkerTypeAlloc();
   s_exactMatchColor   = _AllocColor();
   s_partialMatchColor = _AllocColor();
   _default_color( s_exactMatchColor,   0xffffff, _rgb(255,128,0),   F_BOLD );
   _default_color( s_partialMatchColor, 0xffffff, _rgb(128,128,128), F_BOLD );
}

void close_form()
{
   p_active_form._delete_window();
}

int check_for_project()
{
   _str ext;

   ext = _project_get_filename();

   if (strcmp( substr( ext, length( ext ) - 2, 3 ), "vpe" ) == 0) {
      return 0;
   } else {
      return 1;
   }
}

int preparse_project( int *id )
{
   int status = 0;

   *id = _xmlcfg_open( _project_get_filename(), &status );

   return status;
}

int project_find_files( int xml, int index )
{
   int temp;

   if (index < 0) {
      return 0;
   }

   if (_xmlcfg_get_name( xml, index ) == "Files") {
      return index;
   }

   temp = project_find_files( xml, _xmlcfg_get_first_child( xml, index ) );
   if (temp != 0) {
      return temp;
   }

   temp = project_find_files( xml, _xmlcfg_get_next_sibling( xml, index ) );
   if (temp != 0) {
      return temp;
   }

   return 0;
}

void parse_project( int xml, int index, _str basic_name )
{
   int last=0;
   int idx;
   int child;
   int how;
   _str name;

   if (index < 0)
      return;

   idx = index;
   int idx2;
   int new_idx;

   do {
      if ((_xmlcfg_get_name( xml, idx ) == "F") && (_xmlcfg_get_attribute( xml, idx, "N", "" ) != "")) {
         name = _xmlcfg_get_attribute( xml, idx, "N", "" );
         s_files[last++] = name;
         opf_files._insert_text(name"\n");
      }

      child = _xmlcfg_get_first_child( xml, idx );
      if (child >= 0)
         parse_project( xml, child, "" );

      idx2 = idx;
      idx = _xmlcfg_get_next_sibling( xml, idx );
   } while (idx >= 0);
   opf_files.top();
   opf_files.refresh();
}

void forget_project( int tree )
{
   _xmlcfg_close( tree );
}

void open_project_file.on_load()
{
   int index;

   // Checking if we have opened project...
   if (check_for_project() == 0) {
      _message_box( "Please open project first..." );
      close_form();
      return;
   }
   opf_files._set_focus();
}

void opf_file_name.on_create()
{
   setEditFont( opf_file_name, opf_filt_font );
}

void opf_files.on_create()
{
   p_line_numbers_len = 0;
   p_KeepPictureGutter = false;

   int xml_id = 0;
   int no_files = 0;
   int i;

   if (preparse_project( &xml_id )) {
      _message_box( "Failed to load project file..." );
      close_form();
   }

   no_files = project_find_files( xml_id, 0 );
   parse_project( xml_id, no_files, "" );
   forget_project( xml_id );
}

void open_project_file.on_resize()
{
   /*
          +--------------------------------+
          |          opf_file_name         |   } fixed height
          +--------------------------------+
          |                                |   \
          |                                |    |
          |            opf_files           |    |  variable height
          |                                |    |
          |                                |   /
          +--------------------+-----------+
          |    opf_status1     |opf_status2|   } fixed height
          +--------------------+-----------+

           \__________________/ \_________/
                2/3 width        1/3 width
   */

   int clientwidth  = p_active_form.p_width;
   int clientheight = p_active_form.p_height;
   int hpad         = opf_file_name.p_x;
   int vpad         = opf_file_name.p_y;
   int fnpad        = 20; // Since the right inner border of a
   // sunken field is more pronounced, we align to this instead of
   // the outer border. Hence, the extra 20 units.

   // Calculate horizontal dimensions
   opf_files.p_width    = clientwidth - hpad * 2;
   opf_file_name.p_width = opf_files.p_width + fnpad;
   opf_status1.p_width   = (opf_files.p_width * 2/3) - hpad;
   opf_status2.p_width   = opf_files.p_width - opf_status1.p_width;
   opf_status2.p_x       = opf_status1.p_width + hpad * 2;

   // Calculate vertical dimensions
   opf_files.p_height = clientheight - (vpad * 4 +
                         opf_file_name.p_height +
                         opf_status1.p_height);
   opf_files.p_y      = opf_file_name.p_y + opf_file_name.p_height + vpad;
   opf_status1.p_y     = opf_files.p_y + opf_files.p_height + vpad;
   opf_status2.p_y     = opf_status1.p_y;
}

void opf_files.'ENTER'()
{
   _str name = opf_files.get_current_line();

   // If after stripping path filename remains the same, we should append project directory
   // to filename as the name is relative to project path. Otherwise we should use the name
   // as is.
   if ((strip_filename( name, "D" ) == name) || (substr( name, 1, 1 ) :== ".")) {
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
   _str regex = ".*";
   _str ch;
   int i;
   int last = length(pattern);
   for (i = 1; i <= last; ++i) {
      ch = substr(pattern, i, 1);
      if (pos( ch, regex_chars ) !=0) // escape regex characters
         regex :+= "\\"
      regex :+= ch;
      regex :+= ".*";
   }
   return lowcase(regex);
}

int opf_string_match2( _str pattern, _str regex, _str str)
{
   if (pos( pattern, str, 1, 'I' ) != 0)
       return OPF_EXACT_MATCH;

   opf_status1.p_caption = regex;
   if (pos( regex, str, 1, 'UI' ) != 0)
       return OPF_PATTERN_MATCH;

   return OPF_NO_MATCH;
}

int opf_string_match( _str pattern, _str str )
{
   _str regex, string, word, temp;
   int index, found;

   // all strings matches empty string...
   if (pattern == "") {
      return 1;
   }

   // striping leading and trailing blank characters...
   regex = strip( pattern );

   // lowering case...
   regex = lowcase( pattern );
   string = lowcase( str );

   // convering '_', '-' and '\' characters to space...
   // also escaping . character.
   regex = translate( regex, ' ', '_' );
   regex = translate( regex, ' ', '-' );
   regex = translate( regex, ' ', '\\' );
   regex = translate( regex, ' ', '/' );
//   regex = _escape_re_chars( regex );
//   regex = stranslate( regex, "\\.", "." );

   // looking for occurrences of _all_ words in string...
   index = 0;
   found = 0;

   // Last word in the regex expected to be file name. We first check if last word
   // in regex and string matches, and then we check the rest of the words against
   // the path.
   word = strip_last_word( regex );
   str = strip_filename( string, "P" );
   temp = ".*"word".*";
   if (pos( temp, str, 1, 'U' ) == 0) {
      return 0;
   }

   index = 0;
   found = 0;

   // Now checking path...
   str = strip_filename( string, "N" );
   word = strip_last_word( regex );
   while (word != regex) {
      temp = ".*"word".*";
      if (pos( temp, str, 1, 'U' ) != 0) {
         found++;
      }

      word = strip_last_word( regex );
      index++;
   }

   if (found == index) {
      return 1;
   }

   return 0;
}

static void highlight_text(int len, int offset, int color)
{
    int marker = _StreamMarkerAdd(opf_files, offset, len, true, 0, s_markerType, '');
    _StreamMarkerSetTextColor( marker, color );
}

void add_marked_entry( _str caption, _str pattern, _str regex, int type, int &offset )
{
   // add the text
   opf_files._insert_text(caption"\n");

   // mark the text
   if (type == OPF_EXACT_MATCH)
   {
      int where = pos(pattern, caption, 1, "I") - 1;
      int len = length(pattern);
      highlight_text(len, offset+where, s_exactMatchColor);
   }
   else
   {
      int chpos = pos(regex, caption, 1, "UI");
      int plen = length(pattern);
      _str ch;
      int i;
      for (i = 1; i <= plen; ++i) {
         ch = substr(pattern,i,1);
         chpos = pos(ch, caption, chpos, "I");
         highlight_text(1, offset+chpos-1, s_partialMatchColor);
      }
   }

   // bump the offset
   offset += length(caption)+1;
}

void opf_update_files( _str pattern )
{
   opf_files._delete_text(DELETE_TO_END_OF_BUFFER);

   int type, offset = 0;
   _str caption, regex;
   int idx = 0, first_visible = -1, total_visible = 0, total = 0;
   for (idx = 0; idx < s_files._length(); ++idx)
   {
      caption = s_files[idx];
      if ( caption == "") {
         continue;
      }

      ++total;

      // show/hide lines based on pattern
      regex = make_regex(pattern);
      type = opf_string_match2( pattern, regex, caption);
      if (type != OPF_NO_MATCH)
      {
          add_marked_entry(caption, pattern, regex, type, offset);
          ++total_visible;
      }
   }

   // update status
   opf_status2.p_caption = total_visible " of " total/2 " matched";

   // refresh display
   opf_files.top();
   opf_files.refresh();
}

//void open_project_file.'DOWN'()
//{
// _TreeDown();
//}
//
//void open_project_file.'UP'()
//{
// _TreeUp();
//}

void open_project_file.'ESC'()
{
   close_form();
}

void opf_timer_cb( int win_id )
{
   int cur_window;

   _kill_timer( opf_timer_handle );

   cur_window = p_window_id;
   p_window_id = win_id;

   opf_update_files( opf_file_name.p_caption );

   p_window_id = cur_window;
}

void open_project_file.'BACKSPACE'()
{
   opf_file_name.p_caption = substr( opf_file_name.p_caption, 1, length( opf_file_name.p_caption ) - 1 );
   _kill_timer( opf_timer_handle );
   opf_timer_handle = _set_timer( 50, opf_timer_cb, p_active_form.p_window_id );
}

void opf_on_key()
{
   key := event2name( last_event( null, true ) );
   opf_file_name.p_caption = opf_file_name.p_caption""key;
   _kill_timer( opf_timer_handle );
   opf_timer_handle = _set_timer( 50, opf_timer_cb, p_active_form.p_window_id );
}

def  'a'-'z'      = opf_on_key;
def  'A'-'Z'      = opf_on_key;
def  '0'-'9'      = opf_on_key;
def  '_'          = opf_on_key;
def  '.'          = opf_on_key;
def  ' '          = opf_on_key;
def  '/'          = opf_on_key;

_command void _open_project_file() name_info( ',' VSARG2_MACRO )
{
   show( "-mdi -xy open_project_file" );
}


