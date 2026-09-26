# -*- coding: utf-8 -*-
"""
Hardware-Aware Quantization Analysis — AudioCNN
--------------------------------------------------
Covers: parameter count, per-layer MAC breakdown, parameter
memory footprint (FP32/INT8/INT4), real PyTorch FX INT8 static
quantization, manual INT4 weight quantization, and FP32-vs-INT8
inference latency.

IMPORTANT CAVEAT — read before quoting any "MSE"/"accuracy" number
from this script's output comparison section:

  model_fp32 below is NOT trained (no loss.backward() / optimizer
  step anywhere). The "output deviation" numbers this script
  prints compare FP32 vs INT8 vs INT4 outputs of the SAME
  untrained network to each other. That is a valid measure of
  "how much does quantization change this network's own output"
  (useful, real, hardware-relevant). It is NOT a valid measure of
  "denoising accuracy" or "how good the model is" — that would
  require comparing to real clean-audio targets after actual
  training. The script's print statements say "output deviation",
  not "accuracy", on purpose. Keep it that way if you copy these
  numbers anywhere.

The parameter count, MAC breakdown, memory footprint, and latency
numbers ARE valid regardless of training status — they are
properties of the architecture and the quantization scheme
itself, not of what the weights have learned.
"""

import copy
import os
import time

import torch
import torch.nn as nn


# ----------------------------------------------------------------
# 1. Model definition (2,849 parameters)
# ----------------------------------------------------------------
class AudioCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv1d(in_channels=1, out_channels=16, kernel_size=5, stride=1, padding=2),
            nn.ReLU(),
            nn.Conv1d(in_channels=16, out_channels=32, kernel_size=5, stride=1, padding=2),
            nn.ReLU(),
        )
        self.output_layer = nn.Conv1d(in_channels=32, out_channels=1, kernel_size=5, stride=1, padding=2)

    def forward(self, x):
        x = self.features(x)
        x = self.output_layer(x)
        return x


# ----------------------------------------------------------------
# 2. INT4 symmetric per-tensor weight quantization
# ----------------------------------------------------------------
def quantize_int4_weight(weight):
    """Symmetric per-tensor INT4 quantization. Signed range: -8 to +7."""
    max_abs = weight.abs().max()
    scale = torch.tensor(1.0, device=weight.device) if max_abs == 0 else max_abs / 7.0

    q_weight = torch.round(weight / scale)
    q_weight = torch.clamp(q_weight, -8, 7)
    dequant_weight = q_weight * scale

    return q_weight.to(torch.int8), dequant_weight, scale


# ----------------------------------------------------------------
# 3. Latency benchmark helper
# ----------------------------------------------------------------
def benchmark_model(model, input_tensor, warmup=10, runs=50):
    with torch.no_grad():
        for _ in range(warmup):
            _ = model(input_tensor)

    times = []
    with torch.no_grad():
        for _ in range(runs):
            start = time.perf_counter()
            _ = model(input_tensor)
            times.append(time.perf_counter() - start)

    return {"mean": sum(times) / len(times), "min": min(times), "max": max(times)}


def main():
    torch.manual_seed(42)

    model_fp32 = AudioCNN().eval()
    noisy_batch = torch.randn(4, 1, 32000)

    # ------------------------------------------------------------
    # Parameter count
    # ------------------------------------------------------------
    num_params = sum(p.numel() for p in model_fp32.parameters())
    print("=" * 60)
    print("MODEL SIZE")
    print("=" * 60)
    print(f"Total parameters: {num_params}")

    # ------------------------------------------------------------
    # Per-layer MAC breakdown (architecture property — training-independent)
    # ------------------------------------------------------------
    sequence_length = noisy_batch.shape[-1]
    layers = [
        {"name": "Conv1", "cin": 1, "cout": 16, "kernel": 5},
        {"name": "Conv2", "cin": 16, "cout": 32, "kernel": 5},
        {"name": "Output Conv", "cin": 32, "cout": 1, "kernel": 5},
    ]

    print("\n" + "=" * 60)
    print("HARDWARE COMPUTE ANALYSIS (per-layer MACs)")
    print("=" * 60)
    total_macs = 0
    layer_macs = {}
    for layer in layers:
        macs = sequence_length * layer["cin"] * layer["cout"] * layer["kernel"]
        layer_macs[layer["name"]] = macs
        total_macs += macs
        print(f"{layer['name']}: {macs:,} MACs")

    print("-" * 60)
    print(f"Total MACs: {total_macs:,}  ({total_macs / 1e6:.2f} million)")
    print("\nContribution:")
    for name, macs in layer_macs.items():
        print(f"  {name}: {macs / total_macs * 100:.2f}%")

    # ------------------------------------------------------------
    # Parameter memory footprint
    # ------------------------------------------------------------
    fp32_bytes = num_params * 4
    int8_bytes = num_params * 1
    int4_bytes = num_params * 0.5  # 2 values packed per byte

    print("\n" + "=" * 60)
    print("PARAMETER MEMORY ANALYSIS")
    print("=" * 60)
    print(f"FP32: {fp32_bytes} bytes ({fp32_bytes / 1024:.2f} KB)")
    print(f"INT8: {int8_bytes} bytes ({int8_bytes / 1024:.2f} KB)")
    print(f"INT4 (packed): {int4_bytes:.0f} bytes ({int4_bytes / 1024:.2f} KB)")
    print(f"FP32->INT8 compression: {fp32_bytes / int8_bytes:.1f}x")
    print(f"FP32->INT4 compression: {fp32_bytes / int4_bytes:.1f}x")

    # ------------------------------------------------------------
    # Real PyTorch FX static INT8 quantization
    # ------------------------------------------------------------
    from torch.ao.quantization import get_default_qconfig_mapping
    from torch.ao.quantization.quantize_fx import prepare_fx, convert_fx

    qconfig_mapping = get_default_qconfig_mapping("x86")
    model_prepared = prepare_fx(model_fp32, qconfig_mapping, example_inputs=(noisy_batch,))
    model_prepared.eval()
    with torch.no_grad():
        model_prepared(noisy_batch)  # calibration pass
    model_int8 = convert_fx(model_prepared).eval()

    # ------------------------------------------------------------
    # INT4 weight-only quantization (manual, applied to a fresh copy)
    # ------------------------------------------------------------
    model_int4_eval = copy.deepcopy(model_fp32).eval()
    conv_weight_names = {"features.0": "features.0.weight", "features.2": "features.2.weight",
                          "output_layer": "output_layer.weight"}
    int4_weights = {}
    with torch.no_grad():
        for name, param in model_fp32.named_parameters():
            if "weight" in name:
                q_w, dq_w, scale = quantize_int4_weight(param.detach())
                int4_weights[name] = dq_w
        for name, module in model_int4_eval.named_modules():
            if name in conv_weight_names:
                module.weight.copy_(int4_weights[conv_weight_names[name]])

    # ------------------------------------------------------------
    # Output deviation: FP32 vs INT8 vs INT4 (SAME network, own output)
    # NOT an accuracy claim — see module docstring
    # ------------------------------------------------------------
    criterion = nn.MSELoss()
    with torch.no_grad():
        fp32_out = model_fp32(noisy_batch)
        int8_out = model_int8(noisy_batch)
        int4_out = model_int4_eval(noisy_batch)

    int8_deviation = criterion(int8_out, fp32_out).item()
    int4_deviation = criterion(int4_out, fp32_out).item()

    print("\n" + "=" * 60)
    print("OUTPUT DEVIATION vs FP32 (same untrained network)")
    print("NOTE: this measures quantization-induced output change,")
    print("NOT model accuracy or denoising quality — model is untrained.")
    print("=" * 60)
    print(f"INT8 output MSE vs FP32: {int8_deviation:.8f}")
    print(f"INT4 output MSE vs FP32: {int4_deviation:.8f}")

    # ------------------------------------------------------------
    # Latency benchmark (valid regardless of training status)
    # ------------------------------------------------------------
    fp32_timing = benchmark_model(model_fp32, noisy_batch)
    int8_timing = benchmark_model(model_int8, noisy_batch)

    print("\n" + "=" * 60)
    print("FP32 vs INT8 LATENCY (software / CPU reference — not representative")
    print("of a dedicated INT8 hardware accelerator)")
    print("=" * 60)
    print(f"FP32 mean: {fp32_timing['mean'] * 1000:.4f} ms")
    print(f"INT8 mean: {int8_timing['mean'] * 1000:.4f} ms")


if __name__ == "__main__":
    main()
