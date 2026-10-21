#include <stdio.h>

int main(void)
{
    int row;
    int column;
    int character = 'a';

    for (row = 0; row < 2; ++row) {
        for (column = 0; column < 13; ++column) {
            if (column != 0) {
                putchar(' ');
            }
            putchar(character);
            ++character;
        }
        putchar('\n');
    }

    return 0;
}
