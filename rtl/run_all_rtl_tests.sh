#!/bin/bash
# Paste this as a Colab cell (with ! in front of each line, or run as a shell script)
# after uploading the .sv files in this folder to your Colab session.

apt-get install -y iverilog -qq

echo "===== INT8 MAC ====="
iverilog -g2012 -o mac_sim int8_mac.sv tb_int8_mac.sv && vvp mac_sim

echo ""
echo "===== 5-TAP CONV1D ====="
iverilog -g2012 -o conv_sim conv1d_5tap.sv tb_conv1d_5tap.sv && vvp conv_sim

echo ""
echo "===== 16-CHANNEL CONV1D ====="
iverilog -g2012 -o conv16_sim conv1d_16ch.sv tb_conv1d_16ch.sv && vvp conv16_sim

echo ""
echo "===== 32-CHANNEL CONV2 (H5) ====="
iverilog -g2012 -o conv2_sim conv2_32ch.sv tb_conv2_32ch.sv && vvp conv2_sim
