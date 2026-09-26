# -*- coding: utf-8 -*-
"""
Hardware-Aware Quantization Effects on Neural Audio Processing
----------------------------------------------------------------
IMPORTANT — what this script actually measures:

This measures how much a network's OWN output changes when its
activations are quantized to INT8 / INT4 and dequantized back
(simulated fixed-point rounding). It does NOT measure "speech
enhancement accuracy" or "how good the model is" — the CNN below
uses its as-initialized weights and was never trained on a
task/loss. That is fine for this specific purpose (quantization
noise / SNR degradation is a property of the numeric scheme,
not of whether the network was trained) but it is NOT valid
evidence of model accuracy, denoising quality, or task
performance. Don't present these SNR numbers as "the model
performs well" -- only as "quantizing activations to N bits
introduces this much numerical error."

If you want real accuracy claims, you need an actual training
loop (loss.backward() + optimizer.step() across epochs) which
does not currently exist anywhere in the original notebook.
"""

import math
import urllib.request

import torch
import torch.nn as nn

try:
    import torchaudio
    HAS_TORCHAUDIO = True
except ImportError:
    HAS_TORCHAUDIO = False


# ----------------------------------------------------------------
# 1. Model: lightweight 1D CNN audio filter
# ----------------------------------------------------------------
class AudioFilterCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.conv1 = nn.Conv1d(in_channels=1, out_channels=16, kernel_size=5, padding=2)
        self.relu = nn.ReLU()
        self.conv2 = nn.Conv1d(in_channels=16, out_channels=1, kernel_size=5, padding=2)

    def forward(self, x):
        x = self.conv1(x)
        x = self.relu(x)
        x = self.conv2(x)
        return x


# ----------------------------------------------------------------
# 2. Simulated uniform quantization (INT8 / INT4 fixed-point)
# ----------------------------------------------------------------
def simulate_quantization(tensor, num_bits):
    qmin = -(2 ** (num_bits - 1))
    qmax = (2 ** (num_bits - 1)) - 1

    min_val = tensor.min().item()
    max_val = tensor.max().item()

    scale = max(abs(min_val), abs(max_val)) / qmax
    if scale == 0:
        scale = 1e-5

    quantized = torch.clamp(torch.round(tensor / scale), qmin, qmax)
    dequantized = quantized * scale
    return dequantized


def compute_metrics(original, compressed):
    mse = torch.mean((original - compressed) ** 2).item()
    signal_power = torch.mean(original ** 2).item()
    if mse == 0:
        snr = float("inf")
    else:
        snr = 10 * math.log10(signal_power / mse)
    return mse, snr


# ----------------------------------------------------------------
# 3. Load real audio (falls back to synthetic if unavailable)
# ----------------------------------------------------------------
def load_audio(path="sample_audio.wav", target_sr=16000, num_samples=16000):
    if not HAS_TORCHAUDIO:
        print("torchaudio not available — using synthetic tensor.")
        return torch.randn(1, 1, num_samples)

    try:
        waveform, sample_rate = torchaudio.load(path)
        if sample_rate != target_sr:
            resampler = torchaudio.transforms.Resample(orig_freq=sample_rate, new_freq=target_sr)
            waveform = resampler(waveform)
        if waveform.shape[0] > 1:
            waveform = torch.mean(waveform, dim=0, keepdim=True)

        if waveform.shape[1] >= num_samples:
            waveform = waveform[:, :num_samples]
        else:
            waveform = torch.nn.functional.pad(waveform, (0, num_samples - waveform.shape[1]))

        return waveform.unsqueeze(0)
    except Exception as e:
        print(f"Could not load '{path}': {e}. Falling back to synthetic tensor.")
        return torch.randn(1, 1, num_samples)


# ----------------------------------------------------------------
# 4. Main
# ----------------------------------------------------------------
if __name__ == "__main__":
    torch.manual_seed(42)

    audio_tensor = load_audio()

    model = AudioFilterCNN()
    model.eval()

    with torch.no_grad():
        fp32_output = model(audio_tensor)

    int8_output = simulate_quantization(fp32_output, num_bits=8)
    mse_8, snr_8 = compute_metrics(fp32_output, int8_output)

    int4_output = simulate_quantization(fp32_output, num_bits=4)
    mse_4, snr_4 = compute_metrics(fp32_output, int4_output)

    print("--- Quantization-Induced Degradation (activation-level) ---")
    print(f"Model: {type(model).__name__} (untrained weights — see module docstring)")
    print(f"Input shape: {audio_tensor.shape}\n")

    print("[INT8 simulated quantization]")
    print(f"  MSE vs FP32 output: {mse_8:.6f}")
    print(f"  SNR: {snr_8:.2f} dB\n")

    print("[INT4 simulated quantization]")
    print(f"  MSE vs FP32 output: {mse_4:.6f}")
    print(f"  SNR: {snr_4:.2f} dB")
