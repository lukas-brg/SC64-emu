#!/bin/bash

zig build run -- -r test_files/AllSuiteA.bin --headless -o 0x4000 --pc 0x4000 --trace --trace_start 190  --nobankswitch -c 600 &> out_allsuite.txt