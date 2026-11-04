/* Test-only driver: run the same production scanner on 81 input bytes. */
#include <stdio.h>
#include <fcntl.h>
#include <io.h>
#include "../c/DATA.H"
int main(void)
{
    unsigned char table[9][9];
    if (_setmode(0, _O_BINARY) == -1) return 2; /* stdin descriptor = 0 */
    if (fread(table, 1, sizeof table, stdin) != sizeof table) return 2;
    check_table(table);
    return 0;
}
