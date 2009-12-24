#include "slick.sh"

static int (*s_key_func)(typeless &item);
static void swap_array_elements( typeless (&array)[], int a, int b );

void quicksort(typeless (&list)[], int l, int r, int (*key_func)(typeless &item))
{
   s_key_func = key_func;
   rec_quicksort(list, l, r);
}

static int partition(typeless (&list)[], int l, int r)
{
   int i = l-1, j = r;
   int value = (*s_key_func)(list[r]);
   loop
   {
      while ((*s_key_func)(list[++i]) > value)
         ;
      while (value > (*s_key_func)(list[--j]))
      {
         if (j == 1)
            break;
      }
      if (i >= j)
         break;
      swap_array_elements(list, i, j);
   }
   swap_array_elements(list, i, r);
   return i;
}

static void rec_quicksort(typeless (&list)[], int l, int r)
{
   if (r <= l) return;
   int i = partition(list, l, r);
   rec_quicksort(list, l, i-1);
   rec_quicksort(list, i+1, r);
}

static void swap_array_elements( typeless (&array)[], int a, int b )
{
   if ( a < 0 || a >= array._length() || b < 0 || b >= array._length() )
      return;

   typeless vA = array[a];
   array[a] = array[b];
   array[b] = vA;
}


