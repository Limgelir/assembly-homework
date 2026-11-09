#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct { uint16_t word[5]; } Big;
static Big memo[101];
static unsigned char ready[101];

/* Real recursion, with cached results to avoid exponential recomputation. */
const Big *fib(unsigned int n)
{
    const Big *a;
    const Big *b;
    unsigned int i;
    uint32_t carry = 0;
    if (ready[n]) return &memo[n];
    if (n < 2) {
        memo[n].word[0] = (uint16_t)n;
    } else {
        a = fib(n - 1);
        b = fib(n - 2);
        for (i = 0; i < 5; ++i) {
            uint32_t sum = (uint32_t)a->word[i] + b->word[i] + carry;
            memo[n].word[i] = (uint16_t)sum;
            carry = sum >> 16;
        }
    }
    ready[n] = 1;
    return &memo[n];
}

void print_big(const Big *value)
{
    Big copy = *value;
    char digits[25]; /* ceil(log10(2^80)) = 25 */
    unsigned int count = 0;
    unsigned int nonzero;
    do {
        uint32_t remainder = 0;
        int i;
        nonzero = 0;
        for (i = 4; i >= 0; --i) {
            uint32_t part = (remainder << 16) | copy.word[i];
            copy.word[i] = (uint16_t)(part / 10);
            remainder = part % 10;
            nonzero |= copy.word[i];
        }
        digits[count++] = (char)('0' + remainder);
    } while (nonzero);
    while (count != 0) putchar(digits[--count]);
    putchar('\n');
}

int main(void)
{
    char input[64];
    size_t length;
    size_t i;
    unsigned int n = 0;
    puts("Please input n (1-100):");
    if (fgets(input, sizeof input, stdin) == NULL) goto invalid;
    length = strcspn(input, "\r\n");
    if (length == 0 || length > 3) goto invalid;
    for (i = 0; i < length; ++i) {
        if (input[i] < '0' || input[i] > '9') goto invalid;
        n = n * 10 + (unsigned int)(input[i] - '0');
    }
    if (n < 1 || n > 100) goto invalid;
    puts("F(n):");
    print_big(fib(n));
    return 0;
invalid:
    puts("Error: enter 1-3 decimal digits in 1..100.");
    return 1;
}
