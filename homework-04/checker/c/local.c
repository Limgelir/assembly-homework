#include "DATA.H"

int main(void)
{
    /* Automatic local array: this build places it in main's stack frame. */
    unsigned char table[9][9] = TABLE_VALUES;
    check_table(table);
    return 0;
}
