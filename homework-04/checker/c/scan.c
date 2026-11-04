#include <stdio.h>
#include "DATA.H"

static void report_error(unsigned int row, unsigned int column)
{
    printf("%u %u  error\n", row, column);
}

void check_table(const unsigned char table[9][9])
{
    unsigned int row;
    unsigned int column;
    puts("x y");
    for (row = 0; row < 9; ++row) {
        for (column = 0; column < 9; ++column) {
            unsigned int expected = (row + 1) * (column + 1);
            if (table[row][column] != expected) {
                report_error(row + 1, column + 1);
            }
        }
    }
    puts("\naccomplish!");
}
