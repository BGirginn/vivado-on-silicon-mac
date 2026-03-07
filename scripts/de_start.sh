#!/bin/bash

# This script is run whenever the desktop environment has started.
# (with normal user privileges).

script_dir=$(dirname -- "$(readlink -nf $0)")
source "$script_dir/header.sh"
validate_linux

export LD_PRELOAD="/lib/x86_64-linux-gnu/libudev.so.1 /lib/x86_64-linux-gnu/libselinux.so.1 /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libgdk-x11-2.0.so.0"

# First-run only: install tools, fonts, and themes
if [ ! -f "$HOME/.tools_setup_done" ]; then
    bash "$script_dir/setup_tools.sh"
fi

# Idempotent: link Digilent board files into Vivado (fast, safe to run every time)
bash "$script_dir/setup_boards.sh"

if [ -d "/home/user/Xilinx" ]; then
    # Start hw_server in background for USB/XVC JTAG forwarding via xvcd on macOS
    # 2025.1+: Xilinx/VERSION/Vivado/bin/hw_server
    # ~2024.1:  Xilinx/Vivado/VERSION/bin/hw_server
    for hw_server in /home/user/Xilinx/*/Vivado/bin/hw_server \
                     /home/user/Xilinx/Vivado/*/bin/hw_server; do
        [ -f "$hw_server" ] && "$hw_server" \
            -e "set auto-open-servers xilinx-xvc:host.docker.internal:2542" & break
    done
    # Source Vivado environment then launch GUI
    for settings in /home/user/Xilinx/*/Vivado/settings64.sh \
                    /home/user/Xilinx/Vivado/*/settings64.sh; do
        [ -f "$settings" ] && source "$settings" && break
    done
    vivado
else
    f_echo "The installation is incomplete."
    wait_for_user_input
fi
