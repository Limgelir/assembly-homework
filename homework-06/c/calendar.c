#include <stdio.h>
#include <string.h>

int leap_year(int year)
{
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}

int days_in_month(int year, int month)
{
    static const int days[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
    return days[month - 1] + (month == 2 && leap_year(year));
}

int first_weekday(int year, int month)
{
    int y = year - 1;
    int total = y + y / 4 - y / 100 + y / 400 + 1;
    int m;
    for (m = 1; m < month; ++m) total += days_in_month(year, m);
    return total % 7;
}

void render_calendar(int year, int month)
{
    static const char *names[12] = {
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    };
    int first = first_weekday(year, month);
    int count = days_in_month(year, month);
    int column = first;
    int day;
    int i;
    printf("\n%d  %s\nSu Mo Tu We Th Fr Sa\n", year, names[month - 1]);
    for (i = 0; i < first; ++i) printf("   ");
    for (day = 1; day <= count; ++day) {
        printf("%2d", day);
        ++column;
        if (day == count) putchar('\n');
        else if (column == 7) { putchar('\n'); column = 0; }
        else putchar(' ');
    }
}

int read_number(unsigned int max_digits, int *value)
{
    char input[64];
    size_t length;
    size_t i;
    int result = 0;
    if (fgets(input, sizeof input, stdin) == NULL) return 0;
    length = strcspn(input, "\r\n");
    if (length == 0 || length > max_digits) return 0;
    for (i = 0; i < length; ++i) {
        if (input[i] < '0' || input[i] > '9') return 0;
        result = result * 10 + input[i] - '0';
    }
    *value = result;
    return 1;
}

int main(void)
{
    int year;
    int month;
    printf("Please input year (1900-2099): ");
    fflush(stdout);
    if (!read_number(4, &year) || year < 1900 || year > 2099) {
        puts("Error: year must be 1900..2099 (4 digits).");
        return 1;
    }
    printf("Please input month (1-12): ");
    fflush(stdout);
    if (!read_number(2, &month) || month < 1 || month > 12) {
        puts("Error: month must be 1..12 (1-2 digits).");
        return 1;
    }
    render_calendar(year, month);
    return 0;
}
