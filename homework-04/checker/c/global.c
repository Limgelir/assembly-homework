#include "DATA.H"

/* Initialized global array: static storage duration, writable data section. */
unsigned char table[9][9] = TABLE_VALUES;

int main(void)
{
    check_table(table);
    return 0;
}
