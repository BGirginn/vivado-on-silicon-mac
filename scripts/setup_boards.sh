#!/bin/bash

# Idempotently links Digilent vivado-boards board files into the Vivado installation.
# Safe to run on every container start.

BOARDS_SRC="/home/user/vivado-boards/new/board_files"

if [ ! -d "$BOARDS_SRC" ]; then
    echo "vivado-boards not found (skipping board file setup)"
    exit 0
fi

linked=0
# 2025.1+: Xilinx/VERSION/Vivado  ~2024.1: Xilinx/Vivado/VERSION
for vivado_dir in /home/user/Xilinx/*/Vivado/ \
                  /home/user/Xilinx/Vivado/*/; do
    dst="$vivado_dir/data/boards/board_files"
    [ -d "$dst" ] || continue
    for board in "$BOARDS_SRC"/*/; do
        name=$(basename "$board")
        if [ ! -e "$dst/$name" ]; then
            ln -sf "$board" "$dst/$name"
            linked=$((linked + 1))
        fi
    done
done

echo "Board files linked ($linked new)."
