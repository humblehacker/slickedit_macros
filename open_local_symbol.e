////////////////////////////////////////////////////////////////////////////////////////////////
// © by HS2 - 2007-2008
////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////
// 'open local symbol' (ols) - 'list-tags-plus' :)
//
// derived from open_local_symbol.e thankfully posted by asandler (Alexander) here:
//    http://community.slickedit.com/index.php?topic=2245.msg9334#msg9334
// some features added by hs2
// changes:
// 071026   -  added tag filter support
//          -  improved copy/~append to clipboard
//
// 071101   -  added class name (configurable) to symbol list
//          -  added more word separators (wildcards), CaSe sensitivity and begin/end [^,$] support
//             Note that '_' is not longer a separator by default (configurable - @see OLS_WORD_SEPARATORS)
//          -  added C_BACKSPACE to delete last token/separator only
//          -  added end-of-string 'cursor'
//          -  minor form changes
// 071116   -  added quick tag filter support incl. hotkeys (see Defs TB -> Quick Filters)
//          -  fixed a stack-dump occured when <ENTER> with empty tree
// 071117   -  quite a lot of internal changes due to some performance problems
// 071118   -  performance was better but still bad user experience on laaarge buffers (e.g. 'builtins.e')
//             -> solved using (async) timer based design
//             -> change proposal to SlickTeam to resolve an issue with using the Preview TB by user macros
//                @see tagwin.e - _UpdateTagWindow()
// 071121   -  added context menu and a few more config items
// 071123   -  added Preview TB support
// 071127   -  fixed stupid bug in the font setup, changed on_resize(), fixed typo (seperator -> separator)
// 071127+1 -  fixed issue with suffix match and relaxed word order
// 071128   -  maybe expand hidden line on goto tag
//          -  fixed bug in update_return_type _TreeSetCaption was called w/o referencing 'symbols.'tree control
//          -  added on_close handler (ALT-F4 / system menu) could close use w/o notice
//          -  added workaround (solution ?) for sync problem curr. buffer <-> curr. context (tag_clear_context)
// 071205   -  added 'goto line' if just a number is entered as filter (and there is no matching symbol of course)
// 071212   -  dialog is now non-modal and is updated on buffer switch / on_got_focus
//          -  added ALT-modifier (leave filter/caption) which might be useful when switching to another buffer
//             to go to a tag using the current filter (and the dialog is not dismissed)
//          -  added sth. like 1 level history (curr. just the last cfgs are toggled on TAB
// 080218   -  use ';#;' instead of possibly ambiguous '#' as info seperator
// 080405   -  use adaptive timer depending on number of visible tags for 'update_tree' for better user experience
//             even with files containing a HUGE number of symbols as 'slick.sh'
// 080406   -  fixed a few minor issues with auto-activating Preview TB if dialog looses focus
// 080407   -  show references feature
//          -  I've seen VERY RARE situations, where there context was not updated correctly (empty).
//             So it's changed back to the original method incl. tag_clear_context() which seems to ALWAYS work.
// 080417   -  better init all statics on editor invocation - @see definit()
//          -  skip _on_got_focus '_switchbuf_' calls - @see stdprocs.e - _on_got_focus()
//          -  init/reset _ols_window_id to '0' instead of '-1'
//          -  use get_ols_window_id() to retrieve and verify 'ols' p_window_id in callbacks
// 080417   -  bug fix for Preview TB autohide handling in on_got_focus and
//             minor fix in on_lost_focus if the mouse is in Preview TB window

// HS2-2DO: -  clipboard support (paste filter text), convert to tool window, help/description w/ examples
//             use better icons (access specifier !)

// KNOWN ISSUES:
//          -  it's possible that no bitmaps are displayed e.g. if 'ols' is invoked during SE startup/init phase
//             we could use cb_prepare_expand(p_active_form, p_window_id, TREE_ROOT_INDEX); to gain early access
//             to the bitmaps but it seems that is way too expensive !

#define OLS_VERSION  "ols v4.0.8.1 (SE >= v12.0.3)"

#pragma option(strict,on)
// #region Imports   // can't use #region b/c it's not backward compatible to v12.0.3
#include 'slick.sh'
#include 'tagsdb.sh'
#include 'toolbar.sh'

#import "cbrowser.e"
#import "clipbd.e"
#import "context.e"
#import "cutil.e"
#import "main.e"
#import "pushtag.e"
#import "seldisp.e"
#import "stdprocs.e"
#import "tags.e"
#import "tagwin.e"
#import "tagrefs.e"
#import "tbautohide.e"
#import "toolbar.e"
#import "util.e"
// #endregion

#if __VERSION__<13
extern int _find_formobj(_str form_name, _str option='', ...); // not declared in slick.sh for v12.0.3
extern _command typeless show(_str cmdline="", ...);
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// hardwired config defintions

// user defined tag filter - @see tagsdb.sh
// Note: It's not a big deal to add a few more user sets. Could do that on demand...
#define OLS_TAG_FILTER_USER         (VS_TAGFILTER_ANYPROC | VS_TAGFILTER_ANYDATA)

// font config - @see setEditFont
// Note: set to '0' to use the font attributes/settings of the form 'open_local_symbol' (@see below)
#define OLS_FILT_FONT               CFG_DIALOG     // CFG_SBCS_DBCS_SOURCE_WINDOW
#define OLS_TREE_FONT               CFG_DIALOG     // CFG_SBCS_DBCS_SOURCE_WINDOW

// pseudo cursor curr. abusing special '&' char (which underlines the next char in captions as accelerator)
// Any other string or char such as '.', '|', '´' or even '±' is possible
// Note: Be aware that for some fonts underline is visually identical underscore.
#define OLS_EOS                     '&.'  // '&|' to get a kind of an I-beam cursor, or '& ', '&_', etc.

// I think that in almost all use cases filtering is done CaSe insensitive.
// Hence even if one has switched to CaSe sens. filtering it's reset (on exit) that next time 'ols' is started
// we are in the CaSe insensitive mode again.
// However, this can be disabled by setting OLS_CASE_SENS_RESET_ON_EXIT to 'false'.
#define OLS_CASE_SENS_RESET_ON_EXIT true

// used to set p_SpaceY (determines the extra spacing in twips between each line) property of the tree
#define OLS_TREE_LINE_SPACING       24    // SE default: 50

// update delays in [ms]
// Note: Some fine tuning might be needed if 'ols' is not running smoothly (e.g. lags on key presses)
//       OLS_UPDATE_SYMBOLS_TIME is auto-tuned depending on the number of symbols follwing this formula
//       Tupdate = OLS_UPDATE_SYMBOLS_TIME * (1 + (Nsymbols / OLS_UPDATE_SYMBOLS_SCALE)) with
//       Tupdate is limited to OLS_UPDATE_SYMBOLS_TIME_MAX - @see update_tree
#define OLS_UPDATE_SYMBOLS_TIME_MIN 100   // [ms]
#define OLS_UPDATE_SYMBOLS_SCALE    600   // [num symbols]
#define OLS_UPDATE_SYMBOLS_TIME_MAX 500   // [ms]

#define OLS_UPDATE_PREVIEW_TIME     200   // [ms]
#define OLS_UPDATE_REINIT_TIME      200   // [ms]

// used to separate words/tokens - @see events 'word separators' below and get_word_separators()
// Note: '^' / '$' are the only supported regex chars for begin (token) / end matching.
//       '\' might be used to quote e.g. '$' regex (valid part of a symbol name in e.g. Perl)
//       I think there is no need to change this set b/c it may lead to surprising filter results.
#define OLS_WORD_SEPARATORS         ' ,;=#?+-*'

////////////////////////////////////////////////////////////////////////////////////////////////

enum_flags OLS_FLAGS
{
   // include class names 'class::' on filtering
   // Hint: Use a ':' token (Slick-C: '.') to filter classes/members.
   OLS_USE_CLASS_NAME
   // set for smart CaSe sensitivity [per word/token]
   // Note: This is simply done by verifying 'strcmp (word, lowcase (word))'
,  OLS_SMART_CASE_SENS
   // auto-activate / unhide Preview TB (if not set it's only used when already active or (auto)-hidden
,  OLS_AUTO_ACTIVATE_PREVIEW
   // leave an unnamed bookmark @ current location when goto tag or not
   // Note: The opposite happens when a SHIFT/CTRL modifier is pressed on ENTER.
,  OLS_LEAVE_BOOKMARK
   // sort by line (or alpha)
,  OLS_SORT_BY_LINE
   // use 'LINE' type clipboards for copy/append symbols
   // Note: 'CHAR' type is used otherwise and  mult. symbols are appended / concatenated SPACE separated
,  OLS_COPY_APPEND_BY_LINE
   // strict word/token order on filtering
,  OLS_STRICT_WORD_ORDER
   // show return type in tree (excluded from filtering)
   // Note: The current word order setting is visualized in title / status line as follows:
   //       Strict word order ON    (OLS_STRICT_WORD_ORDER set)      -> '101 TAGS- in ...' ('-' appended)
   //       Strict word order OFF   (OLS_STRICT_WORD_ORDER not set)  -> '101 TAGS~ in ...' ('~' appended)
,  OLS_SHOW_RETURN_TYPE
   // set for CaSe sensitivity of *all* words/tokens (OLS_SMART_CASE_SENS is 'overridden').
   // Note: The current CaSe sens. setting is visualized in title / status line as follows:
   //       CaSe sens ON            (OLS_CASE_SENS set)              -> '101 TAGS- in ...' ('TAGS' upcase)
   //       CaSe smart sens ON      (OLS_SMART_CASE_SENS set)        -> '101 Tags~ in ...' ('Tags' capitalized)
   //       CaSe (smart)sens OFF    (OLS_*_CASE_SENS not set)        -> '101 tags~ in ...' ('tags' lowcase)
,  OLS_CASE_SENS
   // initially add a '^' (prefix match) regex on invokation
,  OLS_INITAL_PREFIXMATCH
   // dismiss/close dialog on goto tag
,  OLS_DISMISS
};

// default 'ols' setup: 0x43F == 1087
int def_ols_flags =  OLS_USE_CLASS_NAME   | OLS_SMART_CASE_SENS   | OLS_AUTO_ACTIVATE_PREVIEW   |
                     OLS_LEAVE_BOOKMARK   | OLS_SORT_BY_LINE      | OLS_COPY_APPEND_BY_LINE     |
                     OLS_DISMISS;

// default 'ols' tag filter
// Note: '0' -> use default filter set for 'Defs TB' (def_proctree_flags)
int def_ols_tag_filter = 0;

////////////////////////////////////////////////////////////////////////////////////////////////

// event config
defeventtab open_local_symbol;

def   'a'-'z'     = _ols_on_key;
def   'A'-'Z'     = _ols_on_key;
def   '0'-'9'     = _ols_on_key;
def   '~'         = _ols_on_key; // easy match all destructors ;)
def   ':'         = _ols_on_key; // might be used to match all classes/members
def   '/'         = _ols_on_key;
def   '<'         = _ols_on_key;
def   '>'         = _ols_on_key;
def   '"'         = _ols_on_key;
def   ''''        = _ols_on_key;
def   '_'         = _ols_on_key;
def   '.'         = _ols_on_key;
def   '@'         = _ols_on_key;

// word separators (internally converted to SPACEs) - @see get_word_separators()
def   ' '         = _ols_on_key;
def   ','         = _ols_on_key;
def   ';'         = _ols_on_key;
def   '\'         = _ols_on_key;
def   '='         = _ols_on_key;
def   '#'         = _ols_on_key;
def   '?'         = _ols_on_key;
def   '+'         = _ols_on_key;
def   '-'         = _ols_on_key;
def   '*'         = _ols_on_key;

// case sensitivity hotkeys
// Note: There are also explicit '_ols_on_key_case_sens_on/off' fct.s available)
def   'A-PGUP'    = _ols_on_key_case_sens_toggle;
def   'A-PGDN'    = _ols_on_key_case_sens_toggle;

// regex (hot)keys
// e.g. 'ols ^_'  -> matches all '_' prefixed symbols also containing 'ols' (non-strcit word order)
// e.g. '_ol nu$' -> matches all symbols containing '_ol' which end with 'nu' (here: '_ols_on_key_show_menu')
def   '^'         = _ols_on_key_begin_token_toggle;
def   '!'         = _ols_on_key_begin_token_toggle;
def   '$'         = _ols_on_key_end_toggle;
def   '('         = _ols_on_key_end_toggle;
def   ')'         = _ols_on_key_end_toggle;

// add. regex hotkeys - might be helpful too
def   'A-HOME'    = _ols_on_key_begin_toggle;         // simply toggles a '^' in front of the first token
def   'A-S-HOME'  = _ols_on_key_begin_token_toggle;   // simply toggles a '^' in front of the curr./last token
def   'C-^'       = _ols_on_key_begin_token_toggle;   // simply toggles a '^' in front of the first token
def   'A-END'     = _ols_on_key_end_toggle;           // simply toggles a '$' at the end of the last token

// other
def   'A-M'       = _ols_on_key_show_menu;
def   'TAB'       = _ols_on_key_last_cfg;

// add direct config toggle hotkeys
def   'A-R'       = _ols_on_key_references;
def   'A-T'       = _ols_on_key_show_return_type_toggle;
def   'A-L'       = _ols_on_key_sort_by_line_toggle;
def   'A-O'       = _ols_on_key_strict_word_order_toggle;

// quick type filter hotkeys - might be helpful too
def   'A-F'       = _ols_on_key_quick_type_func;
def   'A-P'       = _ols_on_key_quick_type_proto;
def   'A-D'       = _ols_on_key_quick_type_data;
def   'A-S'       = _ols_on_key_quick_type_struct;
def   'A-C'       = _ols_on_key_quick_type_const;
def   'A-E'       = _ols_on_key_quick_type_else;
def   'A-A'       = _ols_on_key_quick_type_all;

def   'A-B'       = _ols_on_key_quick_type_proctree;
def   'A-Z'       = _ols_on_key_quick_type_proctree;  // add 'easy access' hotkey
def   'A-Y'       = _ols_on_key_quick_type_proctree;  // add 'easy access' hotkey for QWERTZ keymap

def   'A-U'       = _ols_on_key_quick_type_user;
def   'A-X'       = _ols_on_key_quick_type_user;      // add 'easy access' hotkey

// copy(-append) symbols
def   'C-C'       = _ols_on_copy;
def   'C-S-C'     = _ols_on_copy_append;
def   'C-INS'     = _ols_on_copy;
def   'C-S-INS'   = _ols_on_copy_append;

// Brief support
def   'PAD-PLUS'  = _ols_on_copy;
def   'S-PAD-PLUS'= _ols_on_copy_append;

// preview
def   'A-W'       = _ols_on_preview;

// refresh
def   'A-H'       = _ols_on_refresh;
def   'F5'        = _ols_on_refresh;

////////////////////////////////////////////////////////////////////////////////////////////////

#define OLS_FORM_NAME   'open_local_symbol'

_form open_local_symbol {
   p_backcolor=0x80000005;
   p_border_style=BDS_SIZABLE;
   p_caption='Open Local Symbol';
   p_clip_controls=false;
   p_forecolor=0x80000008;
   p_height=6741;
   p_width=11210;
   p_x=4046;
   p_y=1391;
   p_eventtab=open_local_symbol;
   _label symbol_name {
      p_alignment=AL_LEFT;
      p_auto_size=false;
      p_backcolor=0x80000008;
      p_border_style=BDS_SUNKEN;
      p_caption=OLS_EOS;
      p_font_bold=false;
      p_font_italic=false;
      p_font_name='Bitstream Vera Sans Mono';
      p_font_size=8;
      p_font_underline=false;
      p_forecolor=0x80000008;
      p_height=264;
      p_tab_index=2;
      p_width=11084;
      p_word_wrap=false;
      p_x=60;
      p_y=35;
   }
   _tree_view symbols {
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
      p_font_name='Bitstream Vera Sans Mono';
      p_font_size=8;
      p_font_underline=false;
      p_forecolor=0x80000008;
      p_Gridlines=TREE_GRID_NONE;
      p_height=6351;
      p_LevelIndent=0;
      p_LineStyle=TREE_DOTTED_LINES;
      p_multi_select=MS_NONE;
      p_NeverColorCurrent=false;
      p_ShowRoot=false;
      p_AlwaysColorCurrent=false;
      p_SpaceY=OLS_TREE_LINE_SPACING;
      p_scroll_bars=SB_VERTICAL;
      p_tab_index=1;
      p_tab_stop=true;
      p_width=11084;
      p_x=70;
      p_y=324;
      p_eventtab2=_ul2_tree;
   }
}

#define OLS_MENU_NAME   'open_local_symbol_menu'

_menu open_local_symbol_menu {
   "Same as Defs T&B",                    "ols-menu-cmd _ols_on_key_quick_type_proctree",          "","","";
   "Show &all tags",                      "ols-menu-cmd _ols_on_key_quick_type_all",               "","","";
   "&User defined only",                  "ols-menu-cmd _ols_on_key_quick_type_user",              "","","";
   "&Functions only",                     "ols-menu-cmd _ols_on_key_quick_type_func",              "","","";
   "&Prototypes only",                    "ols-menu-cmd _ols_on_key_quick_type_proto",             "","","";
   "&Data only",                          "ols-menu-cmd _ols_on_key_quick_type_data",              "","","";
   "&Structs/classes only",               "ols-menu-cmd _ols_on_key_quick_type_struct",            "","","";
   "&Constants only",                     "ols-menu-cmd _ols_on_key_quick_type_const",             "","","";
   "&Everytag else",                      "ols-menu-cmd _ols_on_key_quick_type_else",              "","","";
   "-","","","","";
   "&References",                         "ols-menu-cmd _ols_on_key_references",                   "","","";
   "Show Return &type",                   "ols-menu-cmd _ols_on_key_show_return_type_toggle",      "","","";
   "Sort by &Line",                       "ols-menu-cmd _ols_on_key_sort_by_line_toggle",          "","","";
   "CaSe sensiti&vty",                    "ols-menu-cmd _ols_on_key_case_sens_toggle",             "","","";
   submenu "&More Options",               "","","" {
      "Include '&Class::' on filtering",  "ols-menu-cmd _ols_on_key_use_class_name_toggle",        "","","";
      "&Smart CaSe sensitivity",          "ols-menu-cmd _ols_on_key_smart_case_sens_toggle",       "","","";
      "&Auto-activate Preview TB",        "ols-menu-cmd _ols_on_key_auto_activate_preview_toggle", "","","";
      "Leave &Bookmark on goto tag",      "ols-menu-cmd _ols_on_key_leave_bookmark_toggle",        "","","";
      "&Dismiss on goto tag",             "ols-menu-cmd _ols_on_key_dismiss_toggle",               "","","";
      "Strict word &Order",               "ols-menu-cmd _ols_on_key_strict_word_order_toggle",     "","","";
      "Inital &Prefix match",             "ols-menu-cmd _ols_on_key_inital_prefixmatch_toggle",    "","","";
      "Cop&y/Append by Line",             "ols-menu-cmd _ols_on_key_copy_append_by_line_toggle",   "","","";
      "-","","","","";
      OLS_VERSION,                        "ols-version",                                           "","","";
   }
   "-","","","","";
   "Cop&y to clipboard",                  "ols-menu-cmd _ols_on_copy",                             "","","";
   "Appe&nd to clipboard",                "ols-menu-cmd _ols_on_copy_append",                      "","","";
   "-","","","","";
   "Activate Previe&w TB",                "ols-menu-cmd _ols_on_preview",                          "","","";
   "Refres&h",                            "ols-menu-cmd _ols_on_refresh",                          "","","";
}

////////////////////////////////////////////////////////////////////////////////////////////////

// some internally used enum/flags/values ...
enum OLS_INIT_TREE_MODE
{
   OLS_INIT_TREE_TAGFILTER
,  OLS_INIT_TREE_INITIAL
,  OLS_INIT_TREE_SORT
};

static _str    _ols_cur_buf_name       = '';
static int     _ols_cur_tree_index     = -1;

static int     _ols_num_context        = 0;
static int     _ols_num_tags           = 0;
static int     _ols_cur_context_id     = 0;

static int     _ols_PreviewTimerId     = -1;
static int     _ols_UpdateTimerId      = -1;
static int     _ols_ReInitTimerId      = -1;

static int     _ols_window_id          = 0;

static boolean _ols_use_tagwin         = false;

typedef struct ols_cfg_
{
   int   flags;
   int   tag_filter;
   _str  filter_text;
} ols_cfg;

static ols_cfg _ols_last_cfg, prev_ols_cfg, curr_ols_cfg;

// used to check if we really need to mark the def_ vars changed
// @see open_local_symbol.on_create
static int  prev_def_ols_tag_filter = 0;
static int  prev_def_ols_flags      = 0;

static int  orig_autohide_delay     = 0;

////////////////////////////////////////////////////////////////////////////////////////////////
definit()
{
   if (arg(1)!='L')
   {
      // better init all statics on editor invocation
      _ols_cur_buf_name    = '';
      _ols_cur_tree_index  = -1;

      _ols_num_context     = 0;
      _ols_num_tags        = 0;
      _ols_cur_context_id  = 0;

      _ols_PreviewTimerId  = -1;
      _ols_UpdateTimerId   = -1;
      _ols_ReInitTimerId   = -1;

      _ols_window_id       = 0;

      _ols_use_tagwin      = false;

      _ols_last_cfg.flags         = def_ols_flags;
      _ols_last_cfg.tag_filter    = def_ols_tag_filter;
      _ols_last_cfg.filter_text   = OLS_EOS;
      prev_ols_cfg = curr_ols_cfg = _ols_last_cfg;
   }
}

defload()
{
   // try to close dialog on re-load if it's still hanging around (not dismissed)
   // HS2-2DO: Even after closing the dialog I'm getting an 'Invalid Function pointer' stack dump ???
   //          The 'Invalid Function pointer' always occurs if the module was recompiled due to changes.
   formwid := _find_formobj(OLS_FORM_NAME);
   if ( formwid > 0 )   formwid._ols_goto_tag( true );

   // HS2-CHG: (old) proposal to avoid unintended idle update of the 'Preview TB'
   // @see tagwin.e - _UpdateTagWindow()
   #if __VERSION__<13
   // check if 'tagwin.e' patch was applied
   int index = find_index( 'maybe_add_tagwin_noupdate_form', PROC_TYPE );
   if ( index ) call_index( OLS_FORM_NAME, index );
   #endif
}

static int get_ols_window_id()
{
   if ( (_ols_window_id > 0) && (!_iswindow_valid( _ols_window_id ) || (_ols_window_id.p_active_form.p_name != OLS_FORM_NAME)) )
      _ols_window_id = 0;
   return _ols_window_id;
}

static void get_word_separators ( _str &word_separators )
{
   word_separators = OLS_WORD_SEPARATORS;

   // I've added a bit lang. specific magic here - could be extended for other langs too...
   // maybe remove '-' from 'word_separators' b/c it's used in Slick event handler symbols
   if ( strieq ( _mdi.p_child.p_mode_name, 'Slick-C' ) )
      word_separators = translate ( word_separators, '', '-', '' );
}

static void PreviewTimerCallback ( int context_id )
{
   _kill_timer ( _ols_PreviewTimerId ); _ols_PreviewTimerId = -1;

   VS_TAG_BROWSE_INFO cm;
   tag_browse_info_init ( cm );
   tag_get_context_info ( context_id, cm );
   cb_refresh_output_tab( cm, true, true, true );
}

static void UpdateTimerCallback ()
{
   _kill_timer ( _ols_UpdateTimerId ); _ols_UpdateTimerId = -1;
   ols_wid := get_ols_window_id();
   if ( !ols_wid ) return;

   orig_wid := p_window_id;
   p_window_id = ols_wid;
   _update_tree ();
   p_window_id = orig_wid;
}

static void ReInitTimerCallback ()
{
   _kill_timer ( _ols_ReInitTimerId ); _ols_ReInitTimerId = -1;
   ols_wid := get_ols_window_id();
   if ( !ols_wid ) return;

   orig_wid := p_window_id;
   p_window_id = ols_wid;
   init_tree ( def_ols_tag_filter, OLS_INIT_TREE_INITIAL );
   p_window_id = orig_wid;
}

static void _update_tree ( boolean on_init_tree = false )
{
   if ( _ols_use_tagwin && ( _ols_PreviewTimerId != -1 ) ) { _kill_timer ( _ols_PreviewTimerId ); _ols_PreviewTimerId = -1; }

   _str  pattern     = substr ( symbol_name.p_caption, 1, length ( symbol_name.p_caption ) - length ( OLS_EOS ) );
   int   index       = symbols._TreeGetFirstChildIndex( TREE_ROOT_INDEX );
   int   first_match = -1, patlen = length ( pattern );

   if ( (patlen == 0) || ((patlen == 1) && (substr ( pattern, 1, patlen ) :== '^')) )
      first_match = _ols_cur_tree_index;

   // prepare string_match params
   // convert all word separators to SPACEs
   get_word_separators ( auto word_separators );
   pattern = translate ( pattern, ' ', word_separators );

   // un-regex special '~'and ':' chars (used for d'tor / class search e.g. in C/C++ buffers)
   // pattern = _escape_re_chars ( pattern );
   pattern = stranslate ( pattern, '\~', '~' );
   pattern = stranslate ( pattern, '\:', ':' );
   pattern = stranslate ( pattern, '\@', '@' );

   patlen = length ( pattern );

   int   hidden, found, count, prev_pos, cur_pos;
   _str  pattmp, name, word, posopt;
   boolean any_word_order  = ( 0 == (def_ols_flags & OLS_STRICT_WORD_ORDER) );
   boolean smart_case_sens = ( 0 != (def_ols_flags & OLS_SMART_CASE_SENS) );
   boolean case_sens       = ( 0 != (def_ols_flags & OLS_CASE_SENS) );

   // HS2-NOT: _TreeBeginUpdate is also done on 1st init_tree()
   if ( !on_init_tree && (index > 0) ) symbols._TreeBeginUpdate(index);

   while ( index >= 0 )
   {
      hidden = 0;
      if ( patlen > 0 )
      {
         name = symbols._TreeGetUserInfo ( index );
         name = substr ( name, 1, pos ( ';#;', name ) -1 );

         // HS2-NOT: inlined string_match to sqeeze out as much performance as possible
         // hidden = string_match ( pattern, name, 0 != (def_ols_flags & OLS_STRICT_WORD_ORDER) ) ? 0 : TREENODE_HIDDEN;

         // looking for occurrences of all pattern tokens in name (in any/strict order)
         // need a copy of pattern b/c strip_last_word is 'dectructive'
         pattmp = pattern;
         found  = count = 0; prev_pos = MAXINT;
         loop
         {
            word = strip_last_word ( pattmp );
            if ( 0 == length ( word ) )   break;

            count++;

            // check for smart CaSe sensitivity per token (maybe overidden by OLS_STRING_MATCH_CASE)
            posopt = ( ( smart_case_sens && strcmp (word, lowcase (word))) || case_sens ) ? 'R' : 'RI';
            cur_pos = pos ( word, name, 1, posopt );
            if ( cur_pos )
            {
               if ( any_word_order )            found++;
               else if ( cur_pos < prev_pos ) { found++; prev_pos = cur_pos; }
            }
         }

         hidden = ( found == count ) ? 0 : TREENODE_HIDDEN;
      }

      if ( (first_match < 0) && !hidden )  first_match = index;

      symbols._TreeSetInfo ( index, -1, 0, 0, hidden );
      index = symbols._TreeGetNextSiblingIndex ( index );
   }

   symbols._TreeEndUpdate(TREE_ROOT_INDEX);
   if ( first_match >= 0 )
   {
      symbols._TreeSetCurIndex( first_match );
      symbols.call_event(CHANGE_SELECTED, first_match, symbols, ON_CHANGE, 'W');
   }

   if ( on_init_tree && !(def_ols_flags & OLS_SORT_BY_LINE) )  symbols._TreeSortCaption(TREE_ROOT_INDEX, 'I');

   symbols._TreeRefresh();
}

static void maybe_add_return_type ( _str &name, _str &return_type, _str &type_name )
{
   // HS2-DBG: maybe_add_return_type
   // if ( pos ( 'var', type_name ) ) say ("name:" name " return_type: " return_type " type_name: " type_name);

   if ( (def_ols_flags & OLS_SHOW_RETURN_TYPE) && ( (length ( return_type ) > 0) || (length ( type_name ) > 0) ) )
   {
      // HS2-DBG: lang. sens. return type hack
      if ( !strcmp (type_name, 'define') )
      {
         if ( strcmp (return_type, 'typeless'   ) )         name = name :+ " " :+ return_type;
      }
      else if ( !strcmp (type_name, 'eventtab'  ) )         name = type_name   :+ " " :+ name;
      else if ( !strcmp (type_name, 'typedef'   ) )         name = type_name   :+ " " :+ return_type :+ " " :+ name;
      else if ( !strcmp (type_name, 'enum'      ) )         name = type_name   :+ " " :+ name;
      else if ( !strcmp (type_name, 'enumc'     ) )         name = name :+ " " :+ return_type;
      else if ( !strcmp (type_name, 'struct'    ) )         name = type_name   :+ " " :+ name;
      else if ( !strcmp (type_name, 'union'     ) )         name = type_name   :+ " " :+ name;
      else if ( !strcmp (substr (return_type, 1, 1), '=') ) name = name :+ " " :+ return_type;
      // else if (  strcmp (type_name, 'include' ) && strcmp (type_name, 'var' ) )
      // else if (  strcmp (type_name, 'include' ) && strcmp (substr (return_type, 1, 1), '=') )
      else if (  strcmp (type_name, 'include'   ) )
      {
         if ( length ( return_type ) > 0 )         name = return_type :+ " " :+ name;
      }
   }
}

static void update_return_type ()
{
   int  index = symbols._TreeGetFirstChildIndex( TREE_ROOT_INDEX );
   if ( index > 0 )  symbols._TreeBeginUpdate(index);
   _str info, name;
   int  context_id;
   while ( index >= 0 )
   {
      info        = symbols._TreeGetUserInfo ( index );
      context_id  = (int)substr( info, pos( ';#;', info ) +3 );

      name = tag_tree_make_caption_fast(VS_TAGMATCH_context,context_id,true,true,false);
      tag_get_detail2( VS_TAGDETAIL_context_type, context_id, auto type_name );
      tag_get_detail2( VS_TAGDETAIL_context_return, context_id, auto return_type );

      maybe_add_return_type ( name, return_type, type_name );
      symbols._TreeSetCaption( index, name );

      index = symbols._TreeGetNextSiblingIndex ( index );
   }
   symbols._TreeEndUpdate(TREE_ROOT_INDEX);
   symbols._TreeRefresh();

}

static void update_sort ()
{
   if ( def_ols_flags & OLS_SORT_BY_LINE )
   {
      // get caption to search for and _TreeCurIndex after init_tree()
      int index      = symbols._TreeCurIndex();
      if ( index > 0 ) cap := symbols._TreeGetCaption( index );

      init_tree ( def_ols_tag_filter, OLS_INIT_TREE_SORT );

      index = symbols._TreeSearch(TREE_ROOT_INDEX, cap, 'P');
      if ( index > 0 ) symbols._TreeSetCurIndex( index );
   }
   else
   {
      symbols._TreeSortCaption(TREE_ROOT_INDEX, 'I');
      // ensure that the current tree item is visible again
      int index      = symbols._TreeCurIndex();
      if ( index > 0 ) symbols._TreeSetCurIndex( index );
      symbols._TreeRefresh();
   }
}

static void _references ( int context_id )
{
   VS_TAG_BROWSE_INFO cm;
   tag_browse_info_init ( cm );
   tag_get_context_info( context_id, cm );
   cm.tag_database = '';

   // HS2-NOT: ripped from proctree.e - proctree_references() [line 1250]:
   if ( _MaybeRetagOccurrences(cm.tag_database) != COMMAND_CANCELLED_RC )
   {
      // reuse or create tagrefs form
      int formwid = _GetReferencesWID();
      if ( !formwid )
      {
         if ( !isEclipsePlugin() )
         {
            formwid=activate_toolbar("_tbtagrefs_form","");
         }
      }
      if ( formwid )
      {
         _ActivateReferencesWindow();
         refresh_references_tab( cm, true );
      }
   }
}

static void update_tree ()
{
   if ( _ols_UpdateTimerId != -1 ) _kill_timer ( _ols_UpdateTimerId ); _ols_UpdateTimerId = -1;
   // adaptive update time is better for files with a huge number of visible tags/symbols (slick.sh)
   int ols_update_symbols_time = OLS_UPDATE_SYMBOLS_TIME_MIN * (1 + (_ols_num_tags / OLS_UPDATE_SYMBOLS_SCALE));
   if ( ols_update_symbols_time > OLS_UPDATE_SYMBOLS_TIME_MAX ) ols_update_symbols_time = OLS_UPDATE_SYMBOLS_TIME_MAX;
   // say ("update_tree: _ols_num_tags = " _ols_num_tags " ols_update_symbols_time = " ols_update_symbols_time);
   _ols_UpdateTimerId = _set_timer ( ols_update_symbols_time, UpdateTimerCallback );
}

static void reinit_tree ()
{
   if ( _ols_ReInitTimerId != -1 ) _kill_timer ( _ols_ReInitTimerId ); _ols_ReInitTimerId = -1;
   _ols_ReInitTimerId = _set_timer ( OLS_UPDATE_REINIT_TIME, ReInitTimerCallback );
}

static _str tag_filter2str ( int tag_filter )
{
   if ( tag_filter == 0 )
      return "Defs TB";
   else if ( tag_filter == -1 )
      return "All";
   else if ( tag_filter == OLS_TAG_FILTER_USER )
      return "User";
   else if ( tag_filter == (VS_TAGFILTER_ANYPROC & ~VS_TAGFILTER_PROTO) )
      return "Func";
   else if ( tag_filter == VS_TAGFILTER_PROTO )
      return "Proto";
   else if ( tag_filter == VS_TAGFILTER_ANYDATA )
      return "Data";
   else if ( tag_filter == VS_TAGFILTER_ANYSTRUCT )
      return "Struct/class";
   else if ( tag_filter == VS_TAGFILTER_ANYCONSTANT )
      return "Const";
   else if ( tag_filter == ( VS_TAGFILTER_ANYTHING & ~(VS_TAGFILTER_ANYPROC | VS_TAGFILTER_ANYDATA | VS_TAGFILTER_ANYSTRUCT | VS_TAGFILTER_ANYCONSTANT) ) )
      return "Else";
   else
      return "???";
}

static void getTitle ( int tag_filter, int num_tags, int num_context, _str &title )
{
   _str buf_name;
   if ( _mdi.p_child.p_DocumentName :!= '' )  buf_name = _mdi.p_child.p_DocumentName;
   else                                      buf_name = _mdi.p_child.p_buf_name;

   if ( buf_name :== '' ) buf_name = 'Untitled<' :+ _mdi.p_child.p_buf_id :+ '>';

   // incl. wkspace - project
   // title := strip_filename ( _workspace_filename,  'DPE' )  :+ " - " :+ strip_filename ( _project_name, 'DPE' ) :+ " - " :+ strip_filename ( buf_name, 'DP' ) :+ " - " :+ buf_name;
   title =  ( num_tags == num_context ) ? num_context : num_tags :+ ' / ' :+ num_context;
   // set CaSe hint
   // tags: def_ols_smart_case_sens    == false && _ols_string_match_case == false [default - changed by hotkey only]
   // Tags: def_ols_smart_case_sens    == true  && _ols_string_match_case == false [default - changed by hotkey only]
   // TAGS: def_ols_string_match_case  == true  [was set/changed by hotkey]
   _str CaSeHint;
   if       ( def_ols_flags & OLS_CASE_SENS )         CaSeHint = ' TAGS';
   else if  ( def_ols_flags & OLS_SMART_CASE_SENS )   CaSeHint = ' Tags';
   else                                               CaSeHint = ' tags';

   if  ( def_ols_flags & OLS_STRICT_WORD_ORDER )      strappend ( CaSeHint, '- [');
   else                                               strappend ( CaSeHint, '~ [');

   title :+= CaSeHint :+ tag_filter2str ( tag_filter ) :+ "] in '" :+ strip_filename ( buf_name, 'DP' ) :+ "' - " :+ buf_name;
}

static void setDefaultTitle ()
{
   _str title;
   getTitle ( def_ols_tag_filter, _ols_num_tags, _ols_num_context, title );
   sticky_message ( title );
   p_active_form.p_caption = title;
}

void _ols_on_key ()
{
   key := event2name (last_event(null, true));
   cap := substr ( symbol_name.p_caption, 1, length ( symbol_name.p_caption ) - length ( OLS_EOS ) );
   lch := last_char ( cap );
   get_word_separators ( auto word_separators );

   // TAB -> SPACE
   if  ( key :== 'TAB' )   key = ' ';

   // suppress chars behind END '$' if OLS_STRICT_WORD_ORDER is set and
   if ( lch :== '$' )
   {
      if ( def_ols_flags & OLS_STRICT_WORD_ORDER ) key = '';
      // in relaxed word order mode a word separator is required following END '$'
      else if ( !pos ( key, word_separators ) )    key = '';
   }

   // always suppress mult. successive word separators
   if ( pos ( key, word_separators ) && pos ( lch, word_separators ) )  key = '';

   // append key and EOS marker
   cap :+= key :+ OLS_EOS;
   symbol_name.p_caption = cap;

   if ( symbols._TreeGetNumChildren(TREE_ROOT_INDEX) > 0 )  update_tree();
}

void _ols_on_key_begin_toggle ()
{
   cap := symbol_name.p_caption;

   if ( first_char ( cap ) :!= '^' )
   {
      cap = stranslate ( cap, '', '^' );
      cap = '^' :+ cap;
   }
   else cap = substr( cap, 2, length( cap ) -1 );

   symbol_name.p_caption = cap;
   update_tree();
}
void _ols_on_key_begin_on ()
{
   cap := symbol_name.p_caption;

   if ( first_char ( cap ) :!= '^' )
   {
      cap = stranslate ( cap, '', '^' );
      cap = '^' :+ cap;
   }

   symbol_name.p_caption = cap;
   update_tree();
}
void _ols_on_key_begin_off ()
{
   cap := symbol_name.p_caption;

   if ( first_char ( cap ) :== '^' )   cap = substr( cap, 2, length( cap ) -1 );

   symbol_name.p_caption = cap;
   update_tree();
}

void _ols_on_key_begin_token_toggle ()
{
   // makes no sense if OLS_STRICT_WORD_ORDER is configured -> re-map to _ols_on_key_begin_toggle
   if ( def_ols_flags & OLS_STRICT_WORD_ORDER )
   {
      _ols_on_key_begin_toggle();
      return;
   }

   cap := substr ( symbol_name.p_caption, 1, length ( symbol_name.p_caption ) - length ( OLS_EOS ) );
   get_word_separators ( auto word_separators );
   lpos_pattern := '[' :+ word_separators :+ ']';

   // HS2-DBG: _ols_on_key_begin_token_toggle
   // message ("len=" length ( cap ) " - lpos = " lastpos( '['word_separators']', cap, MAXINT, 'R' ));
   lastsep := lastpos( '[' :+ word_separators :+ ']', cap, MAXINT, 'R' );
   _str tok;
   if ( length ( cap ) == lastsep )
   {
      tok = substr( cap, lastsep +1, length( cap ) -lastsep );
      // messageNwait ("tok A1: '" tok "' cap: '" cap "'");
      if ( first_char ( tok ) :!= '^' )
      {
         cap = stranslate ( cap, '', '^' );
         tok = '^' :+ tok;
      }
      else tok = substr( tok, 2, length( tok ) -1 );
      // messageNwait ("tok A: '" tok "' cap: '" cap "'");
   }
   else
   {
      tok = substr( cap, lastsep +1, length( cap ) -lastsep );
      cap = substr( cap, 1, lastsep );
      // messageNwait ("tok B1: '" tok "' cap: '" cap "'");
      if ( first_char ( tok ) :!= '^' )
      {
         cap = stranslate ( cap, '', '^' );
         tok = '^' :+ tok;
      }
      else tok = substr( tok, 2, length( tok ) -1 );
      // messageNwait ("tok B2: '" tok "' cap: '" cap "'");
   }

   symbol_name.p_caption = cap :+ tok :+ OLS_EOS;
   update_tree();
}
void _ols_on_key_end_toggle ()
{
   cap := substr ( symbol_name.p_caption, 1, length ( symbol_name.p_caption ) - length ( OLS_EOS ) );
   lch := last_char ( cap );
   get_word_separators ( auto word_separators );

   if (lch :== '^')  return;

   if ( (lch :!= '$') && (lch :!= '') )
   {
      // maybe remove prev. set '$'
      cap = stranslate ( cap, '', '$' );

      if ( pos ( lch, word_separators ) ) cap = substr( cap, 1, length( cap ) -1 );
      cap :+= '$':+ OLS_EOS;
   }
   else  cap = substr( cap, 1, length( cap ) -1 ) :+ OLS_EOS;

   symbol_name.p_caption = cap;
   update_tree();
}

// quick tag filter
void _ols_on_key_quick_type_proctree ()
{
   init_tree ( 0 );
}
void _ols_on_key_quick_type_all ()
{
   init_tree ( -1 );
}
void _ols_on_key_quick_type_user ()
{
   init_tree ( OLS_TAG_FILTER_USER );
}
void _ols_on_key_quick_type_func ()
{
   init_tree ( VS_TAGFILTER_ANYPROC & ~VS_TAGFILTER_PROTO );
}
void _ols_on_key_quick_type_proto ()
{
   init_tree ( VS_TAGFILTER_PROTO );
}
void _ols_on_key_quick_type_data ()
{
   init_tree ( VS_TAGFILTER_ANYDATA );
}
void _ols_on_key_quick_type_struct ()
{
   init_tree ( VS_TAGFILTER_ANYSTRUCT );
}
void _ols_on_key_quick_type_const ()
{
   init_tree ( VS_TAGFILTER_ANYCONSTANT );
}
void _ols_on_key_quick_type_else ()
{
   init_tree ( VS_TAGFILTER_ANYTHING & ~(VS_TAGFILTER_ANYPROC | VS_TAGFILTER_ANYDATA | VS_TAGFILTER_ANYSTRUCT | VS_TAGFILTER_ANYCONSTANT) );
}
void _ols_on_key_references ()
{
   index := symbols._TreeCurIndex();
   if ( index <= 0 ) return;

   symbols._TreeGetInfo ( index, null, null, null, auto hidden );
   if ( hidden != 0 ) return;

   info  := symbols._TreeGetUserInfo ( index );
   context_id := (int)substr( info, pos( ';#;', info ) +3 );

   if ( context_id > 0 ) _references( context_id );

   // re-sync context
   _ols_window_id = p_window_id;
   p_window_id    = _mdi.p_child;
   _UpdateContext ( true );
   p_window_id = _ols_window_id;
}

void _ols_on_key_show_return_type_toggle ()
{
   if ( def_ols_flags & OLS_SHOW_RETURN_TYPE )
      def_ols_flags &= ~OLS_SHOW_RETURN_TYPE;
   else
      def_ols_flags |=  OLS_SHOW_RETURN_TYPE;
   update_return_type ();
}
void _ols_on_key_sort_by_line_toggle()
{
   if ( def_ols_flags & OLS_SORT_BY_LINE )
      def_ols_flags &= ~OLS_SORT_BY_LINE;
   else
      def_ols_flags |=  OLS_SORT_BY_LINE;
   update_sort();
}
void _ols_on_key_case_sens_toggle ()
{
   if ( def_ols_flags & OLS_CASE_SENS )
      def_ols_flags &= ~OLS_CASE_SENS;
   else
      def_ols_flags |=  OLS_CASE_SENS;
   setDefaultTitle ();
   update_tree();
}
void _ols_on_key_case_sens_on ()
{
   def_ols_flags |=  OLS_CASE_SENS;
   setDefaultTitle ();
   update_tree();
}
void _ols_on_key_case_sens_off ()
{
   def_ols_flags &= ~OLS_CASE_SENS;
   setDefaultTitle ();
   update_tree();
}

// sub-menu
void _ols_on_key_use_class_name_toggle ()
{
   if ( def_ols_flags & OLS_USE_CLASS_NAME )
      def_ols_flags &= ~OLS_USE_CLASS_NAME;
   else
      def_ols_flags |=  OLS_USE_CLASS_NAME;
   update_tree();
}
void _ols_on_key_smart_case_sens_toggle ()
{
   if ( def_ols_flags & OLS_SMART_CASE_SENS )
      def_ols_flags &= ~OLS_SMART_CASE_SENS;
   else
      def_ols_flags |=  OLS_SMART_CASE_SENS;
   setDefaultTitle ();
   update_tree();
}
void _ols_on_key_auto_activate_preview_toggle ()
{
   if ( def_ols_flags & OLS_AUTO_ACTIVATE_PREVIEW )
      def_ols_flags &= ~OLS_AUTO_ACTIVATE_PREVIEW;
   else
      def_ols_flags |=  OLS_AUTO_ACTIVATE_PREVIEW;

   only_when_active := (0 == (def_ols_flags & OLS_AUTO_ACTIVATE_PREVIEW));
   _ols_use_tagwin   = _GetTagwinWID ( only_when_active ) || _tbIsAuto("_tbtagwin_form",true);
   // save auto-hide config and temporary disable auto-hide
   orig_autohide_delay  = def_toolbar_autohide_delay;
   if ( _ols_use_tagwin ) def_toolbar_autohide_delay = MAXINT;

   if ( _ols_use_tagwin ) symbols.call_event(CHANGE_SELECTED, symbols._TreeCurIndex(), symbols, ON_CHANGE, 'W');
}
void _ols_on_key_leave_bookmark_toggle()
{
   if ( def_ols_flags & OLS_LEAVE_BOOKMARK )
      def_ols_flags &= ~OLS_LEAVE_BOOKMARK;
   else
      def_ols_flags |=  OLS_LEAVE_BOOKMARK;
}
void _ols_on_key_dismiss_toggle()
{
   if ( def_ols_flags & OLS_DISMISS )
      def_ols_flags &= ~OLS_DISMISS;
   else
      def_ols_flags |=  OLS_DISMISS;
}
void _ols_on_key_strict_word_order_toggle()
{
   if ( def_ols_flags & OLS_STRICT_WORD_ORDER )
      def_ols_flags &= ~OLS_STRICT_WORD_ORDER;
   else
      def_ols_flags |=  OLS_STRICT_WORD_ORDER;
   setDefaultTitle ();
   update_tree();
}
void _ols_on_key_inital_prefixmatch_toggle()
{
   if ( def_ols_flags & OLS_INITAL_PREFIXMATCH )
   {
      def_ols_flags &= ~OLS_INITAL_PREFIXMATCH;
      _ols_on_key_begin_off();
   }
   else
   {
      def_ols_flags |=  OLS_INITAL_PREFIXMATCH;
      _ols_on_key_begin_on();
   }
}

void _ols_on_key_copy_append_by_line_toggle ()
{
   if ( def_ols_flags & OLS_COPY_APPEND_BY_LINE )
      def_ols_flags &= ~OLS_COPY_APPEND_BY_LINE;
   else
      def_ols_flags |=  OLS_COPY_APPEND_BY_LINE;
}

// clipboard support
void _ols_on_copy ()
{
   index := symbols._TreeCurIndex();
   if ( index <= 0 ) return;

   cap   := symbols._TreeGetCaption( index );
   key   := event2name (last_event(null, true));
   text_to_clipboard ( cap, false, (def_ols_flags & OLS_COPY_APPEND_BY_LINE) ? 'LINE' : 'CHAR', '', true );
}

void _ols_on_copy_append ()
{
   index := symbols._TreeCurIndex();
   if ( index <= 0 ) return;

   cap   := symbols._TreeGetCaption( index );
   key   := event2name (last_event(null, true));
   cap   = ( !(def_ols_flags & OLS_COPY_APPEND_BY_LINE) ? ' ' : '' ) :+ cap;
   text_to_clipboard ( cap, true, (def_ols_flags & OLS_COPY_APPEND_BY_LINE) ? 'LINE' : 'CHAR', '', true  );
}

void _ols_on_preview ()
{
   index := symbols._TreeCurIndex();
   int context_id = 0;
   if ( index > 0 )
   {
      symbols._TreeGetInfo ( index, null, null, null, auto hidden );
      if ( hidden != 0 ) return;

      info  := symbols._TreeGetUserInfo ( index );
      context_id = (int)substr( info, pos( ';#;', info ) +3 );

   }
   PreviewTimerCallback( context_id );
}

void _ols_on_refresh ()
{
   init_tree ( def_ols_tag_filter, OLS_INIT_TREE_INITIAL );
}

void symbol_name.on_create ()
{
   if ( OLS_FILT_FONT != 0 )   setEditFont ( symbol_name, OLS_FILT_FONT );
}
void symbol_name.lbutton_up,rbutton_up ()
{
   int x,y;
   mou_get_xy ( x, y );
   _ols_on_key_show_menu ( x, y );
}

void symbols.on_create ()
{
   if ( OLS_TREE_FONT != 0 )
   {
      setEditFont ( symbols, OLS_TREE_FONT );

      // HS2:  workaround for tree control font
      //       Seems that it only takes effect with p_redraw = true ???
      _str font_name = '';
      getEditFont ( OLS_TREE_FONT, font_name );
      symbols.p_font_name = font_name;
   }
}

static void _ols_goto_tag ( boolean dismiss = true, int linenum = -1, int seekpos = -1, int context_id = -1 )
{
   _kill_timer ( _ols_UpdateTimerId );    _ols_UpdateTimerId   = -1;
   _kill_timer ( _ols_PreviewTimerId );   _ols_PreviewTimerId  = -1;
   _kill_timer ( _ols_ReInitTimerId );    _ols_ReInitTimerId   = -1;

   key := event2name (last_event(null, true));

   clrCap := !pos ( 'A-', key, 1 );
   // save curr. filter setup on goto tag
   if ( linenum >= 0 )
   {
      _ols_last_cfg.flags        = def_ols_flags;
      _ols_last_cfg.tag_filter   = def_ols_tag_filter;
      _ols_last_cfg.filter_text  = clrCap ? symbol_name.p_caption : prev_ols_cfg.filter_text;

      prev_ols_cfg               = _ols_last_cfg;
   }

   // don't clear caption if ALT-modifier is pressed (only makes sense if OLS_DISMISS is not set)
   if ( clrCap )  symbol_name.p_caption = '';

   if ( dismiss )
   {
      // Note: CaSe sensitivity is intentionally reset here b/c I think it's better this way.
      //       Just comment/remove this line if it should be a persistent setting..
      if ( OLS_CASE_SENS_RESET_ON_EXIT )  def_ols_flags &= ~OLS_CASE_SENS;

      if ( (prev_def_ols_tag_filter != def_ols_tag_filter) || (prev_def_ols_flags != def_ols_flags) )
         _config_modify_flags(CFGMODIFY_DEFVAR);

      _ols_window_id = 0;
      p_active_form._delete_window();
   }
   clear_message();
   // Note: use cursor_data() instead of p_window_id = _mdi.p_child; for proper Z-order
   cursor_data();

   if ( linenum >= 0 )
   {
      // maybe leave an unnamed bookmark @ the current location
      // check if SHIFT/CTRL modifier is pressed (alt. skip/set bookmark)
      mod := pos ( '[SC]-', key, 1, 'R' );
      // push one if OLS_LEAVE_BOOKMARK (on ENTER) is configured and NO modifiers are pressed
      // -> modifiers can be used to omit adding a bookmark
      // push one if OLS_LEAVE_BOOKMARK (on ENTER) is NOT configured but modifiers are pressed
      // -> modifiers can be used to force adding a bookmark
      if ( (!mod && (def_ols_flags & OLS_LEAVE_BOOKMARK)) || (mod && !(def_ols_flags & OLS_LEAVE_BOOKMARK)) )
      {
         if ( p_RLine != linenum )  push_bookmark();
      }

      p_RLine     = linenum;
      if (seekpos >= 0) _GoToROffset (seekpos); // seekpos == -1 on 'goto line'

      // else p_col = 0;
      center_line();

      // maybe expand hidden line
      if ( _lineflags() & HIDDEN_LF ) expand_line_level();

      // check if SHIFT-CTRL modifiers are pressed (find refs on quit)
      ref := pos ( 'C-S-', key, 1, 'R' );
      if ( ref && (context_id > 0) )
      {
         // leave a bookmark at the (new) target position to flip back easily
         push_bookmark();
         _references( context_id ); // find refs here before calling the _Update* fct.s
         next_ref( false );
      }
      else
      {
         // explicitely _UpdateContextWindow() NOW
         _UpdateContextWindow ( true );
      }
   }
   else if ( _ols_use_tagwin )
   {
      _UpdateTagWindow ( true );
   }

   // retore auto-hide config
   if ( def_toolbar_autohide_delay != orig_autohide_delay )
   {
      def_toolbar_autohide_delay = orig_autohide_delay;
      int tagwin_wid = _tbGetWid ( "_tbtagwin_form" );
      if (tagwin_wid) _tbMaybeAutoHide ( tagwin_wid, true );
   }
}

// used for modified quit of the dialog (skip leaving bookmarks, find refs, etc,)
void symbols.'S-ENTER','C-ENTER','C-S-ENTER','A-ENTER','A-S-ENTER','A-C-ENTER'()
{
   symbols.call_event(CHANGE_LEAF_ENTER, symbols._TreeCurIndex(), symbols, ON_CHANGE, 'W');
}

void symbols.'S-LBUTTON-DOUBLE-CLICK','C-LBUTTON-DOUBLE-CLICK','C-S-LBUTTON-DOUBLE-CLICK','A-LBUTTON-DOUBLE-CLICK','A-S-LBUTTON-DOUBLE-CLICK','A-C-LBUTTON-DOUBLE-CLICK'()
{
   symbols.call_event(CHANGE_LEAF_ENTER, symbols._TreeCurIndex(), symbols, ON_CHANGE, 'W');
}

void symbols.on_change ( int reason, int index )
{
   // re-arm preview timer but only if the dialog is focussed
   if ( _ols_use_tagwin && (reason == CHANGE_SELECTED) && (_get_focus() == _ols_window_id) )
   {
      if ( _ols_PreviewTimerId != -1 ) { _kill_timer ( _ols_PreviewTimerId ); _ols_PreviewTimerId = -1; }

      int context_id = _ols_cur_context_id;
      if ( index > 0 )
      {
         info       := symbols._TreeGetUserInfo ( index );
         context_id  = (int)substr( info, pos( ';#;', info ) +3 );
      }

      _ols_PreviewTimerId = _set_timer ( OLS_UPDATE_PREVIEW_TIME, PreviewTimerCallback, context_id );
   }

   // bail out here except (S/C-)ENTER was pressed
   if ( reason != CHANGE_LEAF_ENTER ) return;

   // if the update timer is not yet expired (very unlikely though) cancel it, _update_tree() and get index
   if ( _ols_UpdateTimerId != -1 )
   {
      // say ("_ols_UpdateTimerId not expired yet: symbol_name: " symbol_name.p_caption);
      _kill_timer ( _ols_UpdateTimerId ); _ols_UpdateTimerId = -1;
      _update_tree ();
      index = symbols._TreeCurIndex();
   }

   // maybe goto selected symbol
   int   context_id = 0, start_linenum = -1, start_seekpos = -1;

   if ( index > 0 )
   {
      symbols._TreeGetInfo ( index, null, null, null, auto hidden );
      if ( hidden == 0 )
      {
         info       := symbols._TreeGetUserInfo ( index );
         context_id  = (int)substr( info, pos( ';#;', info ) +3 );
      }
   }

   // Retrieve the location *before* _ols_goto_tag() calling _UpdateTagWindow() which might unset OUR context !
   if ( context_id > 0 )
   {
      tag_get_detail2( VS_TAGDETAIL_context_start_linenum, context_id, start_linenum );
      tag_get_detail2( VS_TAGDETAIL_context_start_seekpos, context_id, start_seekpos );
   }
   else
   {
      // if just filter text is just a number (and there is no matching symbol of course) we goto that line
      cap := substr ( symbol_name.p_caption, 1, length ( symbol_name.p_caption ) - length ( OLS_EOS ) );
      if ( isinteger ( cap ) )   start_linenum = (int)cap;
   }

   _ols_goto_tag ( 0 != (def_ols_flags & OLS_DISMISS), start_linenum, start_seekpos, context_id );
}

_command void ols_menu_cmd ( _str cmd = '' ) name_info(',')
{
   focus_wid := _get_focus();
   if ( focus_wid && (focus_wid.p_active_form.p_name == OLS_FORM_NAME) )
   {
      index := find_index(cmd,PROC_TYPE|COMMAND_TYPE);
      if (index)  call_index(index);
      else        _message_box ( "Unable to find/call menu cmd '" :+ cmd :+ "'",'', MB_OK|MB_ICONEXCLAMATION );
   }
}

void _ols_on_key_show_menu ( int x = -1, int y = -1 )
{
   if ( x < 0 )
   {
      int h = 0, w = 0;
      int i = symbols._TreeCurIndex();

      if ( i >= 0 ) symbols._TreeGetCurCoord(i, x, y, w, h);
      {
         // Just to be safe. Round twips to nearest pixel.
         _lxy2dxy ( SM_TWIP, x, y );
         _map_xy ( p_window_id, 0, x, y);
         x += 4; y += 5;
      }
   }

   idx := find_index ( OLS_MENU_NAME, oi2type(OI_MENU) );
   if ( !idx ) return;

   menu_handle := p_active_form._menu_load ( idx, 'P' );
   if ( menu_handle < 0 )
   {
      _message_box ( "Unable to load menu: '" :+ OLS_MENU_NAME :+ "'",'', MB_OK|MB_ICONEXCLAMATION );
      return;
   }

   if ( def_ols_tag_filter == 0 )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_quick_type_proctree",          MF_CHECKED,'M');
   if ( def_ols_tag_filter == -1 )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_quick_type_all",               MF_CHECKED,'M');
   if ( def_ols_tag_filter == OLS_TAG_FILTER_USER )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_quick_type_user",              MF_CHECKED,'M');
   if ( def_ols_tag_filter == (VS_TAGFILTER_ANYPROC & ~VS_TAGFILTER_PROTO) )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_quick_type_func",              MF_CHECKED,'M');
   if ( def_ols_tag_filter == VS_TAGFILTER_PROTO )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_quick_type_proto",             MF_CHECKED,'M');
   if ( def_ols_tag_filter == VS_TAGFILTER_ANYDATA )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_quick_type_data",              MF_CHECKED,'M');
   if ( def_ols_tag_filter == VS_TAGFILTER_ANYSTRUCT )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_quick_type_struct",            MF_CHECKED,'M');
   if ( def_ols_tag_filter == VS_TAGFILTER_ANYCONSTANT )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_quick_type_const",             MF_CHECKED,'M');
   if ( def_ols_tag_filter == ( VS_TAGFILTER_ANYTHING & ~(VS_TAGFILTER_ANYPROC | VS_TAGFILTER_ANYDATA | VS_TAGFILTER_ANYSTRUCT | VS_TAGFILTER_ANYCONSTANT) ) )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_quick_type_else",              MF_CHECKED,'M');

   if ( def_ols_flags & OLS_SHOW_RETURN_TYPE )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_show_return_type_toggle",      MF_CHECKED,'M');
   if ( def_ols_flags & OLS_SORT_BY_LINE )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_sort_by_line_toggle",          MF_CHECKED,'M');
   if ( def_ols_flags & OLS_CASE_SENS )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_case_sens_toggle",             MF_CHECKED,'M');

   if ( def_ols_flags & OLS_USE_CLASS_NAME )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_use_class_name_toggle",        MF_CHECKED,'M');
   if ( def_ols_flags & OLS_SMART_CASE_SENS )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_smart_case_sens_toggle",       MF_CHECKED,'M');
   if ( def_ols_flags & OLS_AUTO_ACTIVATE_PREVIEW )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_auto_activate_preview_toggle", MF_CHECKED,'M');
   if ( def_ols_flags & OLS_LEAVE_BOOKMARK )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_leave_bookmark_toggle",        MF_CHECKED,'M');
   if ( def_ols_flags & OLS_DISMISS )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_dismiss_toggle",               MF_CHECKED,'M');
   if ( def_ols_flags & OLS_STRICT_WORD_ORDER )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_strict_word_order_toggle",     MF_CHECKED,'M');
   if ( def_ols_flags & OLS_INITAL_PREFIXMATCH )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_inital_prefixmatch_toggle",    MF_CHECKED,'M');
   if ( def_ols_flags & OLS_COPY_APPEND_BY_LINE )
      _menu_set_state ( menu_handle,"ols-menu-cmd _ols_on_key_copy_append_by_line_toggle",   MF_CHECKED,'M');

   _menu_set_state    ( menu_handle,"ols-version",                                           MF_GRAYED,'M');

   mf_flag := ( symbols._TreeGetNumChildren(TREE_ROOT_INDEX) > 0 ) ? MF_UNCHECKED : MF_GRAYED;
   _menu_set_state    ( menu_handle,"ols-menu-cmd _ols_on_copy",                             mf_flag,'M');
   _menu_set_state    ( menu_handle,"ols-menu-cmd _ols_on_copy_append",                      mf_flag,'M');

   status := _menu_show ( menu_handle, VPM_RIGHTBUTTON, x-1, y-1 );
}

void symbols.rbutton_up ()
{
   int x,y;
   mou_get_xy ( x, y );
   _ols_on_key_show_menu ( x, y );
}

void _ols_on_key_last_cfg ()
{
   // toggle curr. filter setup with last one
   curr_ols_cfg.flags         = def_ols_flags;
   curr_ols_cfg.tag_filter    = def_ols_tag_filter;
   curr_ols_cfg.filter_text   = symbol_name.p_caption;

   def_ols_flags              = prev_ols_cfg.flags;
   def_ols_tag_filter         = prev_ols_cfg.tag_filter;
   symbol_name.p_caption      = prev_ols_cfg.filter_text;

   if ( curr_ols_cfg != prev_ols_cfg )
   {
      prev_ols_cfg = curr_ols_cfg;

      init_tree ( def_ols_tag_filter, OLS_INIT_TREE_INITIAL );
   }
}

static void init_tree ( int tag_filter, int mode = OLS_INIT_TREE_TAGFILTER )
{
   _str title = '';

   // maybe translate filters
   tf  := ( tag_filter           == 0 ) ? def_proctree_flags : tag_filter;
   otf := ( def_ols_tag_filter   == 0 ) ? def_proctree_flags : def_ols_tag_filter;

   // maybe update title
   if ( (mode == OLS_INIT_TREE_TAGFILTER) && (tag_filter != def_ols_tag_filter) )
   {
      getTitle ( tag_filter, _ols_num_tags, _ols_num_context, title );
      sticky_message ( title );
      p_active_form.p_caption = title;
   }

   if ( def_ols_tag_filter != tag_filter ) _config_modify_flags(CFGMODIFY_DEFVAR);
   def_ols_tag_filter = tag_filter;

   if ( (mode == OLS_INIT_TREE_TAGFILTER) && (tf == otf) )   return;

   if ( _ols_UpdateTimerId != -1 ) _kill_timer ( _ols_UpdateTimerId ); _ols_UpdateTimerId = -1;

   // use translated filter to proceed
   tag_filter = tf;

   int context_id = symbols._TreeGetNumChildren(TREE_ROOT_INDEX);
   int index      = TREE_ROOT_INDEX;

   _ols_window_id = p_window_id;
   p_window_id    = _mdi.p_child;

   // derived from proctree.e - _UpdateCurrentTag()
   if ( (mode == OLS_INIT_TREE_INITIAL) || (0 == context_id) )
   {
      // HS2-NOT: Dennis said that _UpdateContext() is sufficient and tag_clear_context shouldn't be used at all
      //          So I'll give it a try...
      // 080407:  I've seen VERY RARE situations, where there context was not updated correctly (empty).
      //          So I'm back to the original method incl. tag_clear_context() which seems to ALWAYS work.
      #if   0
      _UpdateContext ( true );
      #else
      if ( mode == OLS_INIT_TREE_INITIAL )
      {
         // workaround (solution ?) for sync problem curr. buffer <-> curr. context
         tag_clear_context ( p_buf_name );
         _UpdateContext ( true, true );
      }
      else _UpdateContext ( true );
      #endif

      _ols_num_context = tag_get_num_of_context();
      cur_line := p_RLine;

      // Note: Since tag_nearest_context doesn't filter we need to pre-determine the current context_id and
      // set _ols_curr_index to the tree index on context_id match
      // known bug: @see http://community.slickedit.com/index.php?topic=1892.msg8089#msg8089

      _ols_cur_context_id = tag_nearest_context(cur_line, tag_filter);
      //If we're between functions, but in a comment, find the next context.
      if ((tag_current_context() != _ols_cur_context_id) && _in_comment()) {
         _ols_cur_context_id = tag_nearest_context(cur_line, tag_filter, true);
      }
   }

   // keep track of wid and current buffer - see _switchbuf_ols()
   _ols_cur_buf_name = p_buf_name;
   p_window_id = _ols_window_id;

   _ols_cur_tree_index  = -1;
   _ols_num_tags        = 0;

   symbols._TreeBeginUpdate( TREE_ROOT_INDEX ); // _TreeEndUpdate is done in update_tree()
   symbols._TreeDelete( index, "C" );

   for ( context_id = 1; context_id <= _ols_num_context; context_id++ )
   {
      tag_get_context( context_id,
                       auto proc_name,
                       auto type_name,
                       auto file_name,
                       auto start_line_no,
                       auto start_seekpos,
                       auto scope_line_no,
                       auto scope_seekpos,
                       auto end_line_no,
                       auto end_seekpos,
                       auto class_name,
                       auto tag_flags,
                       auto arguments,
                       auto return_type
                     );

      // HS2-NOT: As Dennis explained this WILL BE an alt. way to go.
      //          VS_TAGDETAIL_context_type_id is not avail. in v12.0.3.
      // int ctx_type_id;
      // tag_get_detail2 ( VS_TAGDETAIL_context_type_id, context_id, ctx_type_id );
      // if ( tag_filter_type ( ctx_type_id, tag_filter ) )

      if ( tag_filter_type ( 0, tag_filter, type_name, tag_flags ) )
      {
         name := tag_tree_make_caption_fast(VS_TAGMATCH_context,context_id,true,true,false);
         tag_tree_get_bitmap(0,0,type_name,'',tag_flags,auto leaf_flag,auto pic);

         maybe_add_return_type ( name, return_type, type_name );
         index = symbols._TreeAddItem( 0, name, TREE_ADD_AS_CHILD, pic, pic, -1 );
         _ols_num_tags++;

         name = proc_name;
         if ( (def_ols_flags & OLS_USE_CLASS_NAME) && (class_name :!= '') ) name = class_name :+ '::' :+ name;
         symbols._TreeSetUserInfo( index, name';#;'context_id );
      }

      if ( context_id == _ols_cur_context_id ) _ols_cur_tree_index = index
   }

   if ( _ols_cur_tree_index <= 0 ) _ols_cur_tree_index = symbols._TreeGetFirstChildIndex( TREE_ROOT_INDEX );
   if ( _ols_cur_tree_index  < 0 ) _ols_cur_tree_index = 0;

   getTitle ( def_ols_tag_filter, _ols_num_tags, _ols_num_context, title );
   sticky_message ( title );
   p_active_form.p_caption = title;

   _update_tree( true );
}

void open_local_symbol.on_create ()
{
   // HS2-NOT: use activate_toolbar("_tbtagwin_form","")
   // or  activate_preview() to force creation/activation of the Preview TB
   // activate_toolbar("_tbtagwin_form","");

   // init defaults
   only_when_active := (0 == (def_ols_flags & OLS_AUTO_ACTIVATE_PREVIEW));
   _ols_use_tagwin   = _GetTagwinWID ( only_when_active ) || _tbIsAuto("_tbtagwin_form",true);
   // save auto-hide config and temporary disable auto-hide
   orig_autohide_delay  = def_toolbar_autohide_delay;
   if ( _ols_use_tagwin ) def_toolbar_autohide_delay = MAXINT;

   // store current def_ vars for CFGMODIFY_DEFVAR check on _ols_goto_tag
   prev_def_ols_tag_filter = def_ols_tag_filter;
   prev_def_ols_flags      = def_ols_flags;

   prev_ols_cfg            = _ols_last_cfg;

   if ( def_ols_flags & OLS_INITAL_PREFIXMATCH )   symbol_name.p_caption = '^';  // _ols_on_key_begin_on()

   _ols_cur_buf_name    = '';
   _ols_cur_context_id  = -1;
}

void _switchbuf_ols (_str oldbuffname, _str flag)
{
   // skip _on_got_focus '_switchbuf_' calls - @see stdprocs.e - _on_got_focus()
   if ( flag :== 'W' ) return;

   if ( (_ols_window_id > 0) && (_mdi.p_child.p_buf_name != _ols_cur_buf_name) ) reinit_tree ();
}

void _cbsave_ols ( ... )
{
   if ( (_ols_window_id > 0) && (_mdi.p_child.p_buf_name == _ols_cur_buf_name) ) reinit_tree ();
}

void open_local_symbol.on_got_focus ()
{
   if ( def_toolbar_autohide_delay != MAXINT )
   {
      // update _ols_use_tagwin - maybe Preview TB is not longer active
      only_when_active := (0 == (def_ols_flags & OLS_AUTO_ACTIVATE_PREVIEW));
      _ols_use_tagwin   = _GetTagwinWID ( only_when_active ) || _tbIsAuto("_tbtagwin_form",true);
      // save auto-hide config and temporary disable auto-hide
      orig_autohide_delay  = def_toolbar_autohide_delay;
      if ( _ols_use_tagwin ) def_toolbar_autohide_delay = MAXINT;
   }

   if ( _mdi.p_child.p_buf_name != _ols_cur_buf_name )
   {
      init_tree ( def_ols_tag_filter, OLS_INIT_TREE_INITIAL );
   }
   else
   {
      symbols.call_event(CHANGE_SELECTED, symbols._TreeCurIndex(), symbols, ON_CHANGE, 'W');
   }
}

void open_local_symbol.on_lost_focus ()
{
   _kill_timer ( _ols_UpdateTimerId );    _ols_UpdateTimerId   = -1;
   _kill_timer ( _ols_PreviewTimerId );   _ols_PreviewTimerId  = -1;
   // retore auto-hide config
   if ( def_toolbar_autohide_delay != orig_autohide_delay )
   {
      def_toolbar_autohide_delay = orig_autohide_delay;
      int tagwin_wid = _tbGetWid ( "_tbtagwin_form" );
      if (tagwin_wid) _tbMaybeAutoHide ( tagwin_wid, false );
   }
}

void open_local_symbol.on_close ()
{
   _ols_goto_tag();
}

void open_local_symbol.on_resize ()
{
   int clientW = _dx2lx(p_active_form.p_xyscale_mode,p_active_form.p_client_width);
   int clientH = _dy2ly(p_active_form.p_xyscale_mode,p_active_form.p_client_height);

   symbols.p_width      = clientW - 2 * symbols.p_x;
   symbol_name.p_width  = clientW - 2 * symbol_name.p_x;
   // add 2 (scaled) pixels
   symbol_name.p_width += _dx2lx(p_active_form.p_xyscale_mode, 2);
   symbols.p_height     = clientH - symbols.p_y - symbols.p_x;
}

void open_local_symbol.BACKSPACE,DEL ()
{
   cap := substr ( symbol_name.p_caption, 1, length ( symbol_name.p_caption ) - length ( OLS_EOS ) );
   cap = substr( cap, 1, length( cap ) -1 ) :+ OLS_EOS;
   symbol_name.p_caption = cap;
   update_tree();
}
void open_local_symbol.A_BACKSPACE ()
{
   symbol_name.p_caption = OLS_EOS;
   update_tree();
}
void open_local_symbol.C_BACKSPACE ()
{
   cap := substr ( symbol_name.p_caption, 1, length ( symbol_name.p_caption ) - length ( OLS_EOS ) );
   get_word_separators ( auto word_separators );
   word_separators :+= '^';
   lpos_pattern := '[' :+ word_separators :+ ']';

   // HS2-DBG: C_BACKSPACE
   // message ("len=" length ( cap ) " - lpos = " lastpos( '['word_separators']', cap, MAXINT, 'R' ));
   if ( length ( cap ) == lastpos( '[' :+ word_separators :+ ']', cap, MAXINT, 'R' ) )
      lpos_pattern = '[~' :+ word_separators :+ ']';

   cap = substr ( cap, 1, lastpos( lpos_pattern, cap, MAXINT, 'R' ) ) :+ OLS_EOS;
   symbol_name.p_caption = cap;
   update_tree();
}

// add 'close' shortcuts
void open_local_symbol.A_DEL ()
{
   _ols_goto_tag();
}

_command void ols,list_tags_plus() name_info (','VSARG2_READ_ONLY|VSARG2_REQUIRES_EDITORCTL|VSARG2_MARK)
{
   // show( "-mdi -xy open_local_symbol" );
   show( "-app -xy open_local_symbol" );
}

////////////////////////////////////////////////////////////////////////////////////////////////
// These fct.s could be removed if they are already exisiting in your macro tollbox.
//
static void getEditFont(int fontIndex = CFG_MINIHTML_FIXED, _str &font_name=null, int &font_size=null, int &font_flags=null, int &charset=null)
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
static void setEditFont(typeless control, int fontIndex = CFG_MINIHTML_FIXED)
{
   _str font_name = '';
   typeless font_size = 10;
   typeless font_flags = 0;
   typeless charset=VSCHARSET_DEFAULT;

   getEditFont ( fontIndex, font_name, font_size, font_flags, charset );

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

/**
 * helper for using the clipboard in user macro functions/commands
 *
 * @param text             text to copy/append to clipboard
 * @param doAppend         append given text to the current clipboard
 * @param clipboard_type   'CHAR' , 'LINE' or 'BLOCK'
 * @param clipboard_name   usually ''
 * @param quiet            print status message or not
 *
 * @return  0: OK
 *          TEXT_NOT_SELECTED_RC: empty text - nothing to copy/append
 */
static int text_to_clipboard (_str text = '', boolean doAppend = false, _str clipboard_type = 'CHAR', _str clipboard_name = '', boolean quiet = false)
{
   // say ("text '" text "' doAppend = " doAppend );

   // alternatively use:
   #if 0
      int temp_wid;
      orig_wid := _create_temp_view(temp_wid);

      // missing: handle diff. clipboard_type
      _insert_text ( (doAppend ? ' ' : '' ) :+ text );
      _begin_line();
      select_char();
      _end_line();left();

      if ( doAppend )   append_to_clipboard();
      else              copy_to_clipboard();

      p_window_id=orig_wid;

      _delete_temp_view(temp_wid);
   #endif

   // s.th. to copy ?
   if ( length ( text ) )
   {
      if ( !doAppend )  push_clipboard_itype (clipboard_type,clipboard_name,1,true);
      append_clipboard_text (text);
      if ( !quiet ) message ( "'" text "' " (doAppend ? "appended" : "copied") " to clipboard [" clipboard_type "]");
      return(0);
   }
   else return(TEXT_NOT_SELECTED_RC);
}

