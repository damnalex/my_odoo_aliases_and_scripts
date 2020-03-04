#!/usr/bin/env python3
import sys

# the params of the public functions are positional, and string only

def thisIsATest():
    print('Test Successfulllll')

# ^^^^^^^^^^^ aliasable functions above this line ^^^^^^^^^

if __name__ == "__main__":
    if len(sys.argv) > 1:
        method_name = sys.argv[1]
        method_params = sys.argv[2:]
        method_params = ', '.join(f"'{param}'" for param in method_params)
        eval(f'{method_name}({method_params})')
    else:
        print("Missing arguments, require at least the function name")
