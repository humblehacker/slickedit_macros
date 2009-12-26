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
#define OPF_PATTERN_MATCH 1
#define OPF_EXACT_MATCH   5
#define DELETE_TO_END_OF_BUFFER -2 // used in _editor._delete_text()

class WeightedEntry
{
   private static WeightedEntry s_mempool[] = null;
   int   m_char_weight[] = null;
   int   m_total_weight = 0;
   _str *m_text;
   int   m_lastslash = 0;

   WeightedEntry(_str *text = null)
   {
      m_text = text;
   }
   void update_lastslash()
   {
      m_lastslash = lastpos(FILESEP, *m_text);
   }
   void clear_weight()
   {
      m_char_weight = null;
      m_total_weight = 0;
   }
   void update_total_weight()
   {
      m_total_weight = 0;
      foreach (auto weight in m_char_weight)
      {
         if (weight != null)
            m_total_weight += weight;
      }
   }
   void weight_char_at_pos(int chpos, int multiplier=1)
   {
      /*
          Each character matched is weighted according to the following heruistics:

            4 points for the first character, or for a character immediately
                     following a '/' or '\\'.
            3 points a character following a '_', or a capital letter immediately
                     following a lowercase letter.
            2 points for a character following a '.'.
            1 point for any other character.
      */

      _str ch = substr(*m_text, chpos, 1);
      int pchpos = chpos-1;
      _str pch = (pchpos) ? substr(*m_text, pchpos, 1) : '';
      if (chpos == 1 || pch == FILESEP)
         m_char_weight[chpos] = 4;
      else if (pch == '_' || (pch == lowcase(pch) && ch == upcase(ch)))
         m_char_weight[chpos] = 3;
      else if (pch == '.')
         m_char_weight[chpos] = 2;
      else
         m_char_weight[chpos] = 1;
      if (chpos > m_lastslash)
         m_char_weight[chpos] *= 2;
      m_char_weight[chpos] *= multiplier;
      // give more weight to contiguous blocks
      if (pchpos && m_char_weight[pchpos] != null &&
          m_char_weight[pchpos] > m_char_weight[chpos])
      {
         ++m_char_weight[chpos];
         ch = substr(*m_text, chpos+1, 1);
         // give more weight to last char of contiguous block if at word end
         if (pos("[."FILESEP" ]", ch, 1, "U"))
            ++m_char_weight[chpos];
      }
   }
   static WeightedEntry * new(_str *text = null)
   {
      WeightedEntry *entry = &s_mempool[s_mempool._length()];
      entry->m_text = text;
      return entry;
   }
   static void delete_all()
   {
      s_mempool = null;
   }
};

static void bucketsort(WeightedEntry* (&entries)[])
{
   WeightedEntry* buckets[][];
   int bucket_last[];

   // distribution
   WeightedEntry *entry = null;
   foreach (entry in entries)
   {
      WeightedEntry *(*bucket)[] = &buckets[entry->m_total_weight];
      (*bucket)[bucket->_length()] = entry;
   }

   entries = null;

   // aggregation
   int last_entry = 0;
   WeightedEntry* bucket[];
   int i;
   for (i = buckets._length(); i >= 0; --i)
   {
      foreach (entry in buckets[i])
      {
         entries[entries._length()] = entry;
      }
   }
}

static void swap( WeightedEntry* (&array)[], int a, int b );

static void quicksort(WeightedEntry* (&list)[])
{
   rec_quicksort(list, 0, list._length()-1);
}

static int partition(WeightedEntry* (&list)[], int l, int r)
{
   int i = l-1, j = r;
   int value = list[r]->m_total_weight;
   loop
   {
      while (list[++i]->m_total_weight > value)
         ;
      while (value > list[--j]->m_total_weight)
      {
         if (j == 1)
            break;
      }
      if (i >= j)
         break;
      swap(list, i, j);
   }
   swap(list, i, r);
   return i;
}

static void rec_quicksort(WeightedEntry* (&list)[], int l, int r)
{
   if (r <= l) return;
   int i = partition(list, l, r);
   rec_quicksort(list, l, i-1);
   rec_quicksort(list, i+1, r);
}

static void swap(WeightedEntry* (&array)[], int a, int b)
{
   if ( a < 0 || a >= array._length() || b < 0 || b >= array._length() )
      return;

   WeightedEntry* vA = array[a];
   array[a] = array[b];
   array[b] = vA;
}


static _str s_files[];
static int  opf_filt_font       =  CFG_DIALOG;
static int  opf_timer_handle    =  0;
static int  s_markerType        = -1;
static int  s_exactMatchColor   = -1;
static int  s_partialMatchColor = -1;

definit()
{
   s_files             = null;
   s_markerType        = _MarkerTypeAlloc();
   s_exactMatchColor   = _AllocColor();
   s_partialMatchColor = _AllocColor();
   _default_color( s_exactMatchColor,   0xffffff, _rgb(255,128,0),   F_BOLD );
   _default_color( s_partialMatchColor, 0xffffff, _rgb(128,128,128), F_BOLD );
}

static void close_form()
{
   WeightedEntry.delete_all();
   p_active_form._delete_window();
}

void _prjupdate_opf()
{
   s_files = null;
}

static int check_for_project()
{
   _str ext;

   ext = _project_get_filename();

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
   int temp;

   if (index < 0)
   {
      return 0;
   }

   if (_xmlcfg_get_name( xml, index ) == "Files")
   {
      return index;
   }

   temp = project_find_files( xml, _xmlcfg_get_first_child( xml, index ) );
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
   int idx;
   int child;
   int how;
   _str name;

   if (index < 0)
      return;

   idx = index;
   int idx2;
   int new_idx;

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

      idx2 = idx;
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
      if (pos( ch, regex_chars ) != 0)
         regex :+= "\\"; // escape regex characters
      regex :+= ch;
      regex :+= ".*";
   }
   return lowcase(regex);
}

static boolean weight_exact_match(_str &pattern, int &match_start, WeightedEntry &curr_entry)
{
   int chpos = pos( pattern, *curr_entry.m_text, match_start, 'I' );
   if (chpos == 0)
      return false;

   match_start = chpos;
   int last = match_start + pattern._length();
   for (; chpos < last; ++chpos)
   {
      curr_entry.weight_char_at_pos(chpos, 2);
   }
   return true;
}

static boolean weight_regex_match(_str &pattern, _str &regex, int &match_start, WeightedEntry &curr_entry)
{
   int chpos = pos( regex, *curr_entry.m_text, match_start, 'UI' );
   if (chpos == 0)
      return false;

   match_start = chpos;
   _str ch;
   int i, last = pattern._length();
   for (i = 1; i <= last; ++i)
   {
      ch = substr(pattern, i, 1);
      chpos = pos(ch, *curr_entry.m_text, chpos, "I");
      curr_entry.weight_char_at_pos(chpos);
   }
   return true;
}

static void choose_max_entry(WeightedEntry &max_entry, WeightedEntry curr_entry)
{
   if (curr_entry.m_total_weight > max_entry.m_total_weight)
      max_entry = curr_entry;
}

static void weight_match(_str &pattern, _str &regex, WeightedEntry &max_entry)
{
   int pattern_len = pattern._length();
   if (pattern_len == 0)
      return;

   max_entry.update_lastslash();
   int match_start = 1;
   WeightedEntry curr_entry = max_entry;
   loop
   {
      curr_entry.clear_weight();

      if (!weight_exact_match(pattern, match_start, curr_entry))
         if (pattern_len == 1 || // if single char fails, look no further.
            !weight_regex_match(pattern, regex, match_start, curr_entry))
            break;

      curr_entry.update_total_weight();
      choose_max_entry(max_entry, curr_entry);
      ++match_start;
   }
}

static void highlight_text(int offset, int len, int color)
{
   int marker = _StreamMarkerAdd(opf_files, offset, len, false, 0, s_markerType, '');
   _StreamMarkerSetTextColor( marker, color );
}

static void add_weighted_entry(WeightedEntry &entry, int &offset)
{
   // add the text
   _str text = *entry.m_text"\n";
   opf_files._insert_text(text);

   // mark the text
   if (entry.m_char_weight != null)
   {
      int i, last = entry.m_text->_length();
      for (i = 1; i <= last; ++i)
      {
         if (entry.m_char_weight[i])
            highlight_text(offset+i-1, 1, s_exactMatchColor);
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
   _str regex = make_regex(pattern);
   opf_status1.p_caption = regex;
   int pattern_len = pattern._length();
   WeightedEntry.delete_all();
   WeightedEntry *entries[] = null;
   WeightedEntry *entry;
   int idx, last_file = 0, last = s_files._length();
   for (idx = 0; idx < last; ++idx)
   {
      entry = WeightedEntry.new(&s_files[idx]);

      weight_match(pattern, regex, *entry);

      if (entry->m_total_weight > 0 || pattern_len == 0)
      {
         entries[last_file] = entry;
         ++last_file;
      }
   }

   // sort list by weight
   if (pattern != '')
      bucketsort(entries);

   // add entries to list edit control
   int offset = 0;
   foreach (entry in entries)
   {
      if (entry->m_total_weight || pattern == '')
         add_weighted_entry(*entry, offset);
   }

   // update status
   opf_status2.p_caption = entries._length() " of " s_files._length() " matched";

   // refresh display
   opf_files.top();
   opf_files.refresh();
}

void open_project_file.on_load()
{
   int index;

   // Checking if we have opened project...
   if (check_for_project() == 0)
   {
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
   p_readonly_mode = true;

   if (s_files._isempty())
   {
      message("loading project paths...");
      int xml_id = 0;
      int no_files = 0;

      if (preparse_project( &xml_id ))
      {
         _message_box( "Failed to load project file..." );
         close_form();
      }

      no_files = project_find_files( xml_id, 0 );
      s_files = null;
      parse_project( xml_id, no_files, "" );
      s_files._sort('F');
      forget_project( xml_id );
      message("Done.");
   }

   _assert(!s_files._isempty());

   int idx;
   for (idx = 0; idx < s_files._length(); ++idx)
   {
      opf_files._insert_text(s_files[idx]"\n");
   }
   opf_status2.p_caption = "0 of " s_files._length() " matched";
   opf_files.top();
   opf_files.refresh();
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
   opf_files.p_height = clientheight - (vpad * 4 +
                                        opf_file_name.p_height +
                                        opf_status1.p_height);
   opf_files.p_y      = opf_file_name.p_y + opf_file_name.p_height + vpad;
   opf_status1.p_y    = opf_files.p_y + opf_files.p_height + vpad;
   opf_status2.p_y    = opf_status1.p_y;
}

void opf_files.'ENTER'()
{
   _str name = opf_files.get_current_line();

   // If after stripping path filename remains the same, we should append project directory
   // to filename as the name is relative to project path. Otherwise we should use the name
   // as is.
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

   _kill_timer( opf_timer_handle );

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
def  '\'          = opf_on_key;

_command void _open_project_file() name_info( ',' VSARG2_MACRO )
{
   show( "-mdi -xy open_project_file" );
}


