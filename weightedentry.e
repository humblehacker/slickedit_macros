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

         // filenames are weighted double
         if (chpos > m_lastslash)
            m_intrinsic_char_weight[chpos] *= 2;
      }
   }

   int weight_char_at_pos(int chpos)
   {
      m_char_weight[chpos] = m_intrinsic_char_weight[chpos];

      // give more weight to contiguous blocks
      int pchpos = chpos - 1;
      if (pchpos && m_char_weight[pchpos] != null &&
          m_char_weight[pchpos] > m_char_weight[chpos])
      {
         m_char_weight[chpos] += m_char_weight[pchpos];
         _str ch = substr(*m_text, chpos+1, 1);
         // give more weight to last char of contiguous block if at word end
         if (pos("[."FILESEP" ]", ch, 1, "U"))
            ++m_char_weight[chpos];
      }
      return m_char_weight[chpos];
   }

   boolean weight_single_match(_str &pattern, int match_start)
   {
      // find 'pattern' in 'm_text', and store indices of matching
      // characters in 'matches'. Can't change any state
      // unless all characters in 'pattern' have been found.
      int matches[];
      int chpos = match_start;
      _str ch;
      int i, last = pattern._length();
      for (i = 1; i <= last; ++i)
      {
         if (chpos > m_text->_length()) return false;
         ch = substr(pattern, i, 1);
         chpos = pos(ch, *m_text, chpos, "I");
         if (!chpos) return false;
         if (i == 1) match_start = chpos;
         matches[matches._length()] = chpos;
         ++chpos;
      }

      // all characters in 'pattern' have been found.
      // Calculate the weights and update the state.
      clear_weight();
      m_match_start = match_start;
      int match;
      foreach (match in matches)
         m_total_weight += weight_char_at_pos(match);

      return true;
   }

   void weight_match(_str &pattern)
   {
      if (pattern._length() == 0)
      {
         clear_weight();
         return;
      }

      int max_weight = 0, max_match_start = 1;
      int match_start = 1;
      loop
      {
         if (!weight_single_match(pattern, match_start))
            break;

         if (m_total_weight > max_weight)
         {
            max_weight = m_total_weight;
            max_match_start = m_match_start;
         }
         match_start = m_match_start+1;
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
         weight_single_match(pattern, max_match_start);
      }
   }
};

void bucketsort(WeightedEntry* (&entries)[])
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


