#!/bin/bash

CHECK_DIR=$1
OUTPUT_FILE=$2

> "$OUTPUT_FILE"

find "/root/demo/store/clog/log_pool" -type f | while read -r file; do
	if [[ "$actual_size" == 0* ]]; then
        echo "$file $apparent_size" >> "$OUTPUT_FILE"
        rm -rf $file
    fi
done
