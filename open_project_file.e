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

#pragma option( strict, on )

defeventtab open_project_file;

_form open_project_file {
   p_backcolor=0x80000005;
   p_border_style=BDS_SIZABLE;
   p_caption='Open Project File';
   p_clip_controls=false;
   p_forecolor=0x80000008;
   p_height=6741;
   p_width=11210;
   p_x=4046;
   p_y=1391;
   p_eventtab=open_project_file;
   _label opf_file_name {
      p_alignment=AL_LEFT;
      p_auto_size=false;
      p_backcolor=0x80000008;
      p_border_style=BDS_SUNKEN;
      p_caption='';
      p_font_bold=false;
      p_font_italic=false;
      p_font_name='Tahoma';
      p_font_size=8;
      p_font_underline=false;
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
      p_font_bold=false;
      p_font_italic=false;
      p_font_name='Tahoma';
      p_font_size=8;
      p_font_underline=false;
      p_forecolor=0x80000008;
      p_Gridlines=TREE_GRID_NONE;
      p_height=6351;
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
}

static int opf_tree_font  = CFG_DIALOG;
static int opf_filt_font  = CFG_DIALOG;

static int opf_timer_handle = 0;

// the indispensable setEditFont macro by Ding
/**
 * Set edit control fonts
 * <pre>
 * Font Index:
 * Command Line,                 CFG_CMDLINE
 * Status Line,                  CFG_STATUS
 * SBCS/DBCS Source Windows,     CFG_SBCS_DBCS_SOURCE_WINDOW
 * Hex Source Windows,           CFG_HEX_SOURCE_WINDOW
 * Unicode Source Windows,       CFG_UNICODE_SOURCE_WINDOW
 * File Manager Windows,         CFG_FILE_MANAGER_WINDOW
 * Diff Editor Source Windows,   CFG_DIFF_EDITOR_WINDOW
 * Parameter Info,               CFG_FUNCTION_HELP
 * Parameter Info Fixed,         CFG_FUNCTION_HELP_FIXED
 * Menu,                         CFG_MENU
 * Dialog,                       CFG_DIALOG
 * HTML Proportional,            CFG_MINIHTML_PROPORTIONAL
 * HTML Fixed,                   CFG_MINIHTML_FIXED
 * </pre>
 *
 * @author Ding Zhaojie
 *
 * @param control    editor control
 * @param fontIndex  font index
 *
 * @see _use_edit_font()
 */
void opf_getEditFont(int fontIndex = CFG_MINIHTML_FIXED, _str &font_name=null, int &font_size=null, int &font_flags=null, int &charset=null)
{
   _str fname = '';
   typeless fsize = 10;
   typeless fflags = 0;
   typeless fcharset=VSCHARSET_DEFAULT;
   parse _default_font(fontIndex) with fname ',' fsize ',' fflags ',' fcharset ',';

   if ( font_name    != null  )  font_name  = fname;
   if ( font_size    != null  )  font_size  = fsize;
   if ( font_flags   != null  )  font_flags = fflags;
   if ( charset      != null  )  charset    = fcharset;
}

void opf_setEditFont(typeless control, int fontIndex = CFG_MINIHTML_FIXED)
{
   _str font_name = '';
   typeless font_size = 10;
   typeless font_flags = 0;
   typeless charset=VSCHARSET_DEFAULT;

   opf_getEditFont( fontIndex, font_name, font_size, font_flags, charset );

   int font_bold              = font_flags & F_BOLD;
   int font_italic            = font_flags & F_ITALIC;
   int font_strike_thru       = font_flags & F_STRIKE_THRU;
   int font_underline         = font_flags & F_UNDERLINE;

   /* Turn off redraw so we are not recalculating the world on every little font change. */
   control.p_redraw           = false;
   control.p_font_name        = font_name;
   control.p_font_size        = font_size;
   control.p_font_bold        = (font_bold != 0);
   control.p_font_italic      = (font_italic != 0);
   control.p_font_strike_thru = (font_strike_thru != 0);
   control.p_font_charset     = charset;
   control.p_redraw           = true;
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
   int idx;
   int child;
   int how;
   _str name;

   if (index < 0)
      return;

   idx = index;
   int idx2;
 
   do {
      if ((_xmlcfg_get_name( xml, idx ) == "F") && (_xmlcfg_get_attribute( xml, idx, "N", "" ) != "")) {
         name = _xmlcfg_get_attribute( xml, idx, "N", "" );
         _TreeAddItem( 0, 
                       name, 
                       TREE_ADD_AS_CHILD, 
                       _pic_doc_w,
                       _pic_doc_w,
                       -1 );
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
   opf_setEditFont( opf_file_name, opf_filt_font );
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

   forget_project( xml_id );

   // Workaround for tree font issue. Credit goes to HS2!
   opf_setEditFont( opf_files, opf_tree_font );

   _str font_name = '';
   opf_getEditFont( opf_tree_font, font_name );
   opf_files.p_font_name = font_name;
}

void open_project_file.on_resize()
{
   int clientwidth      = p_active_form.p_width;
   int clientheight     = p_active_form.p_height;

   opf_files.p_width      = clientwidth - 260;
   opf_file_name.p_width  = opf_files.p_width + 20;

   opf_files.p_height     = clientheight - opf_files.p_y - 440;
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

_str opf_make_regex( _str pattern )
{
   _str regex = ".*";
   _str ch;
   int i;
   int last = length(pattern);
   for (i = 1; i <= last; ++i) {
      regex :+= substr(pattern, i, 1);
      regex :+= ".*";
   }
   return lowcase(regex);
}

int opf_string_match2( _str pattern, _str str )
{
   _str regex = opf_make_regex(pattern);
   if (pos( regex, str, 1, 'U' ) == 0) {
      return 0;
   }
   return 1;
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
   int idx = 0;

   do {
      idx = opf_files._TreeGetNextIndex( idx, "H" );
      if (idx < 0) {
         break;
      }

      if (opf_files._TreeGetCaption( idx ) == "") {
         continue;
      }

      if (!opf_string_match2( pattern, opf_files._TreeGetCaption( idx ) )) {
         opf_files._TreeSetInfo( idx, -1, -1, -1, TREENODE_HIDDEN );
      } else {
         opf_files._TreeSetInfo( idx, -1, -1, -1, 0 );
      }
   } while (1);

   opf_files._TreeRefresh();
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
