#!/bin/bash

zig build run -- -r test_files/AllSuiteA.bin --headless -o 0x4000 --pc 0x4000 --log_start 190 -c 420 2> out_allsuite.txt