#!/bin/bash

zig build
valgrind --tool=callgrind --callgrind-out-file=callgrind.out zig-out/bin/zic20 
gprof2dot -f callgrind callgrind.out | dot -Tpdf -o callgrind.out.pdf

