#include "slick.sh"

class WeightedEntry
{
   int   m_intrinsic_char_weight[] = null;
   int   m_char_weight[] = null;
   int   m_total_weight = 0;
   _str *m_text;
   int   m_lastslash = 0;
   int   m_match_start = 0;

   WeightedEntry()
   {
      m_text = null;
   }
   void set_text(_str *text)
   {
      m_text = text;
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
   void calc_intrinsic_weights()
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

      _str ch;
      int pchpos;
      int chpos, last = m_text->_length();
      for (chpos = 1; chpos <= last; ++chpos)
      {
         m_intrinsic_char_weight[chpos] = 1;
         pchpos = chpos-1;
         _str pch = (pchpos) ? substr(*m_text, pchpos, 1) : '';
         if (chpos == 1 || pch == FILESEP)
            m_intrinsic_char_weight[chpos] = 4;
         else if (pch == '.')
            m_intrinsic_char_weight[chpos] = 2;
         else
         {
            ch = substr(*m_text, chpos, 1);
            if (pch == '_' || (pch == lowcase(pch) && ch == upcase(ch)))
               m_intrinsic_char_weight[chpos] = 3;
         }
      }
   }
   void weight_char_at_pos(int chpos, int multiplier=1)
   {
      m_char_weight[chpos] = m_intrinsic_char_weight[chpos];

      if (chpos > m_lastslash)
         m_char_weight[chpos] *= 2;
      m_char_weight[chpos] *= multiplier;
      // give more weight to contiguous blocks
      int pchpos = chpos - 1;
      if (pchpos && m_char_weight[pchpos] != null &&
          m_char_weight[pchpos] > m_char_weight[chpos])
      {
         ++m_char_weight[chpos];
         _str ch = substr(*m_text, chpos+1, 1);
         // give more weight to last char of contiguous block if at word end
         if (pos("[."FILESEP" ]", ch, 1, "U"))
            ++m_char_weight[chpos];
      }
   }
   boolean weight_exact_match(_str &pattern)
   {
      int chpos = pos( pattern, *m_text, m_match_start, 'I' );
      if (chpos == 0)
         return false;

      clear_weight();
      m_match_start = chpos;
      int last = m_match_start + pattern._length();
      for (; chpos < last; ++chpos)
      {
         weight_char_at_pos(chpos, 2);
      }
      return true;
   }
   boolean weight_regex_match(_str &pattern, _str &regex)
   {
      int chpos = pos( regex, *m_text, m_match_start, 'UI' );
      if (chpos == 0)
         return false;

      clear_weight();
      m_match_start = chpos;
      _str ch;
      int i, last = pattern._length();
      for (i = 1; i <= last; ++i)
      {
         ch = substr(pattern, i, 1);
         chpos = pos(ch, *m_text, chpos, "I");
         weight_char_at_pos(chpos);
      }
      return true;
   }
   boolean weight_single_match(_str &pattern, _str &regex)
   {
      if (!weight_exact_match(pattern))
         if (pattern._length() == 1 || // if single char fails, look no further.
             !weight_regex_match(pattern, regex))
            return false;

      update_total_weight();
      return true;
   }
   void weight_match(_str &pattern, _str &regex)
   {
      int pattern_len = pattern._length();
      if (pattern_len == 0)
      {
         clear_weight();
         return;
      }

      int max_weight = 0, max_match_start = 1;
      m_match_start = 1;
      loop
      {
         if (!weight_single_match(pattern, regex))
            break;

         if (m_total_weight > max_weight)
         {
            max_weight = m_total_weight;
            max_match_start = m_match_start;
         }
         ++m_match_start;
      }

      if (!max_weight)
      {
         clear_weight();
         return;
      }

      // Optimization: the last match is most likely to be the heaviest,
      // so we will only have to go back and re-weigh in rare cases.
      if (max_weight != m_total_weight)
      {
         m_match_start = max_match_start;
         weight_single_match(pattern, regex);
      }
   }

};

static void bucketsort(WeightedEntry* (&entries)[])
{
   WeightedEntry* buckets[][];

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


