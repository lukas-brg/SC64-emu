#!/bin/bash

if [ $# -eq 0 ]; then
    xa test.asm -o test_files/test.o65
    zig build run -- -r test_files/test.o65
else
    output_file="${1%.*}.o65"
    xa "$1" -o ${output_file}
    zig build run -- -r ${output_file}
fi

