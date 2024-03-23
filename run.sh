#!/bin/bash

if [ $# -eq 0 ]; then
    xa test.asm -o test.o65
    zig run src/main.zig -- test.o65
else
    output_file="${1%.*}.o65"
    xa "$1" -o ${output_file}
    zig run src/main.zig -- ${output_file}
    
fi

