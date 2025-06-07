#include <iostream>
#include "../include/test.h"

int main() {
    using namespace std;
    for(auto i = 0; i < 10; i++) {
        std::int32_t a = random_number_seedless();
        std::int32_t b = random_number_seedless();
        cout << a << " + " << b << " = " << add(a, b) << endl;
    }
    return 0;
}