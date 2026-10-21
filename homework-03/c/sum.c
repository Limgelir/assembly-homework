#include <stdio.h>
#include <string.h>

/* This loop mirrors the 16-bit assembly loop. The result is <= 5050. */
unsigned int sum_to(unsigned int n)
{
    unsigned int total = 0;
    unsigned int i;
    for (i = 1; i <= n; ++i) {
        total += i;
    }
    return total;
}

int main(void)
{
    char input[64];
    size_t length;
    size_t i;
    unsigned int n = 0;

    puts("Please input n (1-100):");
    if (fgets(input, sizeof input, stdin) == NULL) {
        puts("Error: enter 1-3 decimal digits in 1..100.");
        return 1;
    }
    length = strcspn(input, "\r\n");
    if (length == 0 || length > 3) {
        puts("Error: enter 1-3 decimal digits in 1..100.");
        return 1;
    }
    for (i = 0; i < length; ++i) {
        if (input[i] < '0' || input[i] > '9') {
            puts("Error: enter 1-3 decimal digits in 1..100.");
            return 1;
        }
        n = n * 10 + (unsigned int)(input[i] - '0');
    }
    if (n < 1 || n > 100) {
        puts("Error: enter 1-3 decimal digits in 1..100.");
        return 1;
    }
    printf("Sum:\n%u\n", sum_to(n));
    return 0;
}
