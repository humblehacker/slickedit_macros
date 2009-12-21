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

#define OPF_EXACT_MATCH   1
#define OPF_PATTERN_MATCH 2

static int opf_tree_font  = CFG_DIALOG;
static int opf_filt_font  = CFG_DIALOG;

static int opf_timer_handle = 0;

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
         new_idx = _TreeAddItem( 0,
                                 name,
                                 TREE_ADD_AS_CHILD,
                                 _pic_doc_w,
                                 _pic_doc_w,
                                 -1 );
         _TreeSetUserInfo(new_idx, OPF_EXACT_MATCH);
      }

      child = _xmlcfg_get_first_child( xml, idx );
      if (child >= 0)
         parse_project( xml, child, "" );

      idx2 = idx;
      idx = _xmlcfg_get_next_sibling( xml, idx );
   } while (idx >= 0);
}

void sort_tree( int index )
{
   if (index < 0) {
      return;
   }

   _TreeSortCaption( index, 'P', 'F' );

//   sort_tree( _TreeGetFirstChildIndex( index ) );
//   sort_tree( _TreeGetNextSiblingIndex( index ) );
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
}

void opf_file_name.on_create()
{
   setEditFont( opf_file_name, opf_filt_font );
}

void tree_reset_moreflag(int ItemIndex, int flag)
{
   int ShowChildren, NonCurrentBMIndex, CurrentBMIndex, lineNumber;
   int currentFlags;
   opf_files._TreeGetInfo(ItemIndex, ShowChildren, NonCurrentBMIndex,
                          CurrentBMIndex, currentFlags, lineNumber);
   currentFlags &= ~flag;
   opf_files._TreeSetInfo(ItemIndex, ShowChildren, NonCurrentBMIndex,
                          CurrentBMIndex, currentFlags);
}

void tree_set_moreflag(int ItemIndex, int flag)
{
   int ShowChildren, NonCurrentBMIndex, CurrentBMIndex, lineNumber;
   int currentFlags;
   opf_files._TreeGetInfo(ItemIndex, ShowChildren, NonCurrentBMIndex,
                          CurrentBMIndex, currentFlags, lineNumber);
   currentFlags |= flag;
   opf_files._TreeSetInfo(ItemIndex, ShowChildren, NonCurrentBMIndex,
                          CurrentBMIndex, currentFlags);
}

static int hide_flag = TREENODE_HIDDEN;

void tree_hide_node(int idx)
{
   tree_set_moreflag(idx, hide_flag);
}

void tree_show_node(int idx)
{
   tree_reset_moreflag(idx, hide_flag);
}

void double_tree()
{
   _str name;
   int count = opf_files._TreeGetNumChildren(0);
   int new_idx, userinfo, total = 0;
   int idx = 0;
   for (idx = opf_files._TreeGetNextIndex( idx, "H" ); idx >= 0;
        idx = opf_files._TreeGetNextIndex( idx, "H" )) {

      userinfo = _TreeGetUserInfo(idx);

      // skip new items
      if (userinfo == OPF_PATTERN_MATCH) {
         continue;
      }

      ++total;

      // hide original items
      tree_hide_node(idx);
      tree_set_moreflag(idx, TREENODE_BOLD);

      // get caption
      name = _TreeGetCaption(idx);

      // add a copy and mark PATTERN_MATCH
      new_idx = _TreeAddItem( 0,
                              name,
                              TREE_ADD_AS_CHILD,
                              _pic_doc_w,
                              _pic_doc_w,
                              -1 );
      tree_show_node(new_idx);
      _TreeSetUserInfo(new_idx, OPF_PATTERN_MATCH);
   }
   opf_status2.p_caption = total " of " total " matched";
}

void opf_files.on_create()
{
   int xml_id = 0;
   int no_files = 0;
   int i;

   if (preparse_project( &xml_id )) {
      _message_box( "Failed to load project file..." );
      close_form();
   }

   no_files = project_find_files( xml_id, 0 );
   parse_project( xml_id, no_files, "" );
   sort_tree( 0 );
   double_tree();

   forget_project( xml_id );

   // Workaround for tree font issue. Credit goes to HS2!
   setEditFont( opf_files, opf_tree_font );

   _str font_name = '';
   getEditFont( opf_tree_font, font_name );
   opf_files.p_font_name = font_name;
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
   opf_files.p_width     = clientwidth - hpad * 2;
   opf_file_name.p_width = opf_files.p_width + fnpad;
   opf_status1.p_width   = (opf_files.p_width * 2/3) - hpad;
   opf_status2.p_width   = opf_files.p_width - opf_status1.p_width;
   opf_status2.p_x       = opf_status1.p_width + hpad * 2;

   // Calculate vertical dimensions
   opf_files.p_height = clientheight - vpad * 4 -
                        opf_file_name.p_height - opf_status1.p_height;
   opf_status1.p_y    = opf_files.p_y + opf_files.p_height + vpad;
   opf_status2.p_y    = opf_status1.p_y;
}

void opf_files.on_destroy()
{
   int index = 0;

   index = _TreeGetFirstChildIndex( 0 );
   while (index > 0) {
      _TreeDelete( index, "" );
      index = _TreeGetFirstChildIndex( 0 );
   }
}

void opf_files.on_change(int reason,int index)
{
   _str name;
   _str proj;
   typeless form;

   if (index < 0)
      return;

   if (reason == CHANGE_LEAF_ENTER) {
      name = _TreeGetCaption( index );

      // If after stripping path filename remains the same, we should append project directory
      // to filename as the name is relative to project path. Otherwise we should use the name
      // as is.
      if ((strip_filename( name, "D" ) == name) || (substr( name, 1, 1 ) :== ".")) {
         proj = _project_get_filename();
         proj = strip_filename( proj, "N" );
         name = proj :+ name;
      }

      // quote name if it includes spaces
      if (pos( " ", name, 1, 'U' ) != 0)
         name = "\""name"\"";

      form = p_active_form;
      e( name );
      form._delete_window();
   }
}

static _str regex_chars = "^$.+*?{}[]()\\|";

_str opf_make_regex( _str pattern )
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

boolean opf_string_match2( _str pattern, _str str, int type )
{
   boolean exact_match = pos( pattern, str, 1, 'I' ) != 0;
   if (type == OPF_EXACT_MATCH)
      return exact_match;

   _str regex = opf_make_regex(pattern);
   opf_status1.p_caption = regex;
   return !exact_match && pos( regex, str, 1, 'UI' ) != 0;
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

void opf_update_tree( _str pattern )
{
   int type;
   _str caption;
   int idx = 0, first_visible = -1, total_visible = 0, total = 0;
   for (idx = opf_files._TreeGetNextIndex( idx, "H" ); idx >= 0;
        idx = opf_files._TreeGetNextIndex( idx, "H" )) {

      caption = opf_files._TreeGetCaption( idx );
      if ( caption == "") {
         continue;
      }

      ++total;

      type = opf_files._TreeGetUserInfo(idx);
      if (opf_string_match2( pattern, caption, type )) {
         tree_show_node(idx);
         ++total_visible;
         if (first_visible == -1)
            first_visible = idx;
      } else {
         tree_hide_node(idx);
      }
   }

   if (first_visible != -1) {
      opf_files._TreeScroll( first_visible );
      opf_files._TreeSetCurIndex( first_visible );
   }
   opf_files._TreeRefresh();
   opf_status2.p_caption = total_visible " of " total/2 " matched";
}

void open_project_file.'DOWN'()
{
   _TreeDown();
}

void open_project_file.'UP'()
{
   _TreeUp();
}

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

   opf_update_tree( opf_file_name.p_caption );

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
