#include <stdio.h>

/* A real function call for each cell, matching the assembly procedure. */
void print_cell(unsigned int row, unsigned int column)
{
    unsigned int product = row * column;
    printf("%u*%u=%u", row, column, product);
    if (column < row) {
        unsigned int spaces = product < 10 ? 4 : 3;
        while (spaces != 0) {
            putchar(' ');
            --spaces;
        }
    }
}

int main(void)
{
    unsigned int row;
    unsigned int column;
    puts("The 9mul9 table:");
    for (row = 9; row != 0; --row) {
        for (column = 1; column <= row; ++column) {
            print_cell(row, column);
        }
        putchar('\n');
    }
    return 0;
}
