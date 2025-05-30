#include <iostream>
#include "../include/test.h"

using std::int32_t;

int32_t random_number_seedless() {
    int32_t* garbage_data = reinterpret_cast<int32_t*>(malloc(32 * sizeof(int32_t)));
    int32_t output = 129512581;
    if(!garbage_data) return output;
    for(auto i = 0; i < 32; i++) {
        output ^= garbage_data[i] * 450 + garbage_data[31 - i] | 12581213 + (garbage_data[i] << 10);
        garbage_data[i] = garbage_data[31 - i] ^ output << 4 + garbage_data[i] | 60 ^ output;
    }
    free(garbage_data);
    return output;
}

int main() {
    using namespace std;
    for(auto i = 0; i < 100; i++) {
        int32_t a = random_number_seedless() % 19;
        int32_t b = random_number_seedless() % 19;
        if(a < 0) a = -a;
        if(b < 0) b = -b;
        if(a > 9) a = (a - 10) + 1;
        if(b > 9) b = (b - 10) + 1;
        cout << a << " + " << b << " = " << add(a, b) << endl;
    }
    return 0;
}