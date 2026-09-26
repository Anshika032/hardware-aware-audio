# Hardware-Aware Audio Quantization

Hardware-aware INT8/INT4 quantization of a lightweight 1D CNN for neural
audio processing, with FPGA/ASIC-oriented SystemVerilog RTL development
and verification — from a single INT8 MAC unit up to a 32-channel Conv2
engine.

## Status

**RTL (hardware): verified.**
- `int8_mac.sv` — INT8 multiply-accumulate unit — verified
- `conv1d_5tap.sv` — 5-tap Conv1D — verified
- `conv1d_16ch.sv` — 16-channel Conv1D — verified
- `conv2_32ch.sv` — 32-output-channel Conv2 engine — verified, all 16,256
  outputs matched against expected values in simulation (Icarus Verilog)

**Not yet done:** parallel MAC architecture, pipelining, stress
verification, PyTorch↔RTL end-to-end numerical validation, synthesis /
resource analysis (LUTs/FFs/DSP/timing), FPGA/ASIC synthesis (this
project is RTL + simulation only so far).

**Python pipeline (quantization analysis): exploratory, not a trained
model.** See caveat below before quoting any accuracy-sounding number
from this repo.

## Important caveat — read before citing any number from this repo

The `AudioCNN` / `AudioFilterCNN` model used in both pipeline scripts is
**not trained** — there is no `loss.backward()` / optimizer step anywhere
in this codebase. The MSE/SNR numbers the scripts print compare the
network's own FP32 output to its own INT8/INT4 output. That is a real,
useful measurement of **quantization-induced numerical error** — it is
**not** a measurement of denoising accuracy, task performance, or "how
good the model is." Don't present these numbers as accuracy claims. A
real accuracy claim requires training against real clean-audio targets
first.

The parameter count, per-layer MAC breakdown, memory footprint, and
latency numbers *are* valid regardless of training status — they're
properties of the architecture and quantization scheme, not of what the
weights have learned.

## Structure

```
rtl/                          SystemVerilog RTL + testbenches
  int8_mac.sv                 INT8 MAC unit
  tb_int8_mac.sv              testbench
  conv1d_5tap.sv              5-tap Conv1D
  tb_conv1d_5tap.sv           testbench
  conv1d_16ch.sv              16-channel Conv1D
  tb_conv1d_16ch.sv           testbench
  conv2_32ch.sv               32-channel Conv2 engine
  tb_conv2_32ch.sv            testbench
  run_all_rtl_tests.sh        runs all RTL testbenches via Icarus Verilog

pipeline/
  quantization_analysis.py         activation-level INT8/INT4 quantization,
                                    SNR degradation, real/synthetic audio input
  hardware_quantization_analysis.py  parameter count, per-layer MAC breakdown,
                                    memory footprint, real PyTorch FX INT8
                                    static quantization, manual INT4 weight
                                    quantization, FP32-vs-INT8 latency
```

## Running the RTL tests

Requires Icarus Verilog (`iverilog`, `vvp`).

```bash
cd rtl
chmod +x run_all_rtl_tests.sh
./run_all_rtl_tests.sh
```

## Running the Python analysis

```bash
cd pipeline
pip install torch
python quantization_analysis.py
python hardware_quantization_analysis.py
```

## Roadmap

- [ ] H6 — parallel MAC architecture
- [ ] H7 — pipelining
- [ ] H8 — stress verification
- [ ] H9 — PyTorch↔RTL end-to-end numerical validation
- [ ] H10 — synthesis / resource analysis (LUTs/FFs/DSP/timing)
- [ ] H11 — performance analysis
- [ ] Train the model on a real dataset (LibriSpeech / Common Voice) so
      accuracy claims become valid, not just quantization-noise claims
- [ ] Perceptual audio-quality listening test (noisy / FP32 / INT8)
- [ ] Actual FPGA/ASIC synthesis

## License

MIT — see [LICENSE](LICENSE).
