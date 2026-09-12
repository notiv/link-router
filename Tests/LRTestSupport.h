#import <Foundation/Foundation.h>

static NSUInteger LRFailures = 0;

#define LRAssert(condition, message) \
    do { \
        if (!(condition)) { \
            LRFailures += 1; \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, message); \
        } \
    } while (0)

static int LRFinishTests(void) {
    if (LRFailures == 0) {
        printf("PASS\n");
        return 0;
    }
    fprintf(stderr, "FAIL: %lu assertion(s)\n", (unsigned long)LRFailures);
    return 1;
}
