#include "slick.sh"

#pragma option( strict, on )

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
void setEditFont(typeless control, int fontIndex = CFG_MINIHTML_FIXED)
{
   _str font_name = '';
   typeless font_size = 10;
   typeless font_flags = 0;
   typeless charset=VSCHARSET_DEFAULT;

   getEditFont( fontIndex, font_name, font_size, font_flags, charset );

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

void getEditFont(int fontIndex = CFG_MINIHTML_FIXED, _str &font_name=null, int &font_size=null, int &font_flags=null, int &charset=null)
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


