#include "./include/test.h"
#include <iostream>

using std::int32_t;

int32_t prev = 129512581;
int32_t random_number_seedless() {
    int32_t* garbage_data = reinterpret_cast<int32_t*>(malloc(32 * sizeof(int32_t)));
    int32_t output = prev;
    if(!garbage_data) return output;
    for(auto i = 0; i < 32; i++) {
        output ^= garbage_data[i] * 450 + garbage_data[31 - i] | 12581213 + (garbage_data[i] << 10);
        garbage_data[i] = garbage_data[31 - i] ^ output << (4 + garbage_data[i] | 60 ^ output);
    }
    free(garbage_data);
    prev = output;
    int32_t a = output % 19;
    if(a < 0) a = -a;
    if(a > 9) a = (a - 10) + 1;
    return a;
}