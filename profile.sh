#!/bin/bash

timestamp=$(date +"%Y%m%d_%H%M%S")

zig build

valgrind --tool=callgrind --callgrind-out-file=callgrind.out zig-out/bin/sc64 -c 1500000

thres="0.1"

if [ $# -eq 0 ] || [ "$1" = "png" ]; then 
    gprof2dot -f callgrind --node-thres=$thres callgrind.out | dot -Tpng -o callgrind_$timestamp.png
else
    gprof2dot -f callgrind --node-thres=$thres callgrind.out | dot -o callgrind_$timestamp.pdf
fi

