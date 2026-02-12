# 🚀 Jetson Nano (2019 / 4GB) – Production-Grade CUDA LLM Server

This document defines a **reproducible, legacy-optimized deployment pipeline** for running GPU-accelerated LLM inference on the **NVIDIA Jetson Nano 4GB (Tegra X1, Maxwell SM_53, 128 CUDA cores)**.

Because the original Nano is permanently limited to:

- **JetPack 4.6.x**
- **CUDA 10.2**
- **Ubuntu 18.04**
- **GCC 7**
- **Maxwell (sm_53)**

modern CUDA builds frequently break due to:
- `bfloat16` assumptions
- CUDA ≥ 11 toolchain requirements
- C++17 compiler expectations
- new tensor core kernels (unsupported on Maxwell)

Therefore this guide locks `llama.cpp` to a **known-good CUDA 10.2 compatible commit** and applies Maxwell-specific optimizations.

The result is:
- GPU-offloaded inference
- OpenAI-compatible HTTP API
- Systemd-managed persistent model service
- Reproducible build pipeline
- Fully clocked SM_53 kernels
- Production boot-time startup

---

# 📦 System Overview

| Component | Value |
|------------|--------|
| SoC | Tegra X1 |
| GPU | Maxwell GM20B (SM_53) |
| CUDA Cores | 128 |
| RAM | 4GB LPDDR4 |
| VRAM | Shared (Unified Memory) |
| CUDA | 10.2 |
| Max Practical Model | ~2.7B Q4 |
| Recommended Models | ≤ 1.3B |

---

# ⚠️ Hardware Constraints

- 4GB RAM means **swap is mandatory**
- Unified memory means CPU/GPU memory contention
- No tensor cores
- No BF16
- PCIe not involved (on-die GPU)
- Thermal throttling common without cooling
- eMMC/SD card I/O can bottleneck model loading

---

# 🛠 Phase 0 — Base System Preparation

## 0.1 Update System

```bash
sudo apt update && sudo apt upgrade -y
```

Reboot after upgrade.

---

## 0.2 Enable 8GB Swap (CRITICAL)

Without swap, model load will trigger OOM killer.

```bash
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Verify:
```bash
free -h
```

---

## 0.3 Set Maximum Performance Mode

```bash
sudo nvpmodel -m 0
sudo jetson_clocks
```

Confirm:
```bash
sudo jetson_clocks --show
```

---

# 🏗 Phase 1 — CUDA-Compatible llama.cpp Build

## 1.1 Install Dependencies

```bash
sudo apt install -y \
  build-essential \
  cmake \
  git \
  libcurl4-openssl-dev
```

JetPack 4.6 ships CUDA 10.2 preinstalled.

Verify:
```bash
nvcc --version
```

---

## 1.2 Clone and Pin Compatible Commit

The following commit is known to compile cleanly under CUDA 10.2:

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
git checkout a33e6a0
```

Do NOT use latest `master` on Jetson Nano.

---

## 1.3 Build for Maxwell (SM_53)

Maxwell requires explicit architecture targeting.

```bash
mkdir build && cd build

cmake .. \
  -DGGML_CUDA=ON \
  -DGGML_CUDA_F16=ON \
  -DCMAKE_CUDA_ARCHITECTURES=53

cmake --build . --config Release -j$(nproc)
```

Expected Output Includes:
```
-- CUDA detected: 10.2
-- Using CUDA architectures: 53
```

Binary output:
```
build/bin/main
build/bin/server
```

---

# 📂 Phase 2 — System Installation

## 2.1 Install Binaries

```bash
sudo cp bin/main /usr/local/bin/llama-cli
sudo cp bin/server /usr/local/bin/llama-server
sudo chmod +x /usr/local/bin/llama-*
```

Verify:
```bash
llama-cli --help
```

---

## 2.2 Create Model Directory

```bash
sudo mkdir -p /usr/local/share/llama-models
sudo chown -R $USER:$USER /usr/local/share/llama-models
```

Supported format:
```
*.gguf
```

---

# 🧠 Phase 3 — Model Selection Guidelines

⚠ Maxwell + CUDA 10.2 DOES NOT support:

- Tied embeddings
- Llama 3.x
- Qwen 2.5
- SmolLM2
- BF16 models

You will see:
```
output.weight not found
```

## Recommended Models

| Model | Size | Quant | Speed |
|-------|------|--------|--------|
| Qwen1.5-0.5B | 380MB | Q4_K_M | 30+ t/s |
| TinyLlama-1.1B | 670MB | Q4_K_M | 12–15 t/s |
| Phi-1.5 (1.3B) | 900MB | Q4 | 14–16 t/s |
| Phi-2 (2.7B) | 1.8GB | Q4 | 5–6 t/s |

Optimal sweet spot: **1.1B–1.3B**

---

# 🚀 Phase 4 — Production systemd Service

Create:

```bash
sudo nano /etc/systemd/system/llama-server.service
```

---

## Example Service File

```ini
[Unit]
Description=Llama.cpp CUDA LLM Server (Jetson Nano)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/usr/local/share/llama-models

# Maxwell optimization flags
Environment="GGML_CUDA_FORCE_MMQ=1"
Environment="GGML_CUDA_ENABLE_UNIFIED_MEMORY=1"

ExecStart=/usr/local/bin/llama-server \
  -m /usr/local/share/llama-models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  -ngl 99 \
  --ctx-size 2048 \
  --host 0.0.0.0 \
  --port 8080 \
  --embedding

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Replace:
```
User=YOUR_USERNAME
```

---

## Enable Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now llama-server
```

Check:
```bash
systemctl status llama-server
```

---

# 🌐 API Usage

Health check:
```bash
curl http://localhost:8080/health
```

Completion request:
```bash
curl http://localhost:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "prompt": "Explain Maxwell GPUs in one sentence.",
    "max_tokens": 50
  }'
```

Embeddings:
```bash
curl http://localhost:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "input": "Jetson Nano edge AI"
  }'
```

---

# ⚙️ Performance Tuning

## Check CUDA Engagement

Logs should show:
```
Device 0: NVIDIA Tegra X1
```

Monitor:
```bash
journalctl -u llama-server -f
```

Install jtop:
```bash
sudo pip3 install jetson-stats
sudo reboot
jtop
```

Watch:
- GPU load
- RAM usage
- Temperature
- Throttling flags

---

# 🔥 Thermal Recommendations

Jetson Nano throttles at ~80°C.

Recommended:
- Active 5V fan
- Heatsink upgrade
- Avoid enclosed cases

---

# 🧪 Benchmarking Procedure

For reproducible benchmarks:

1. Fix clocks (`jetson_clocks`)
2. Reboot
3. Warm up model (1 dummy request)
4. Run 1000 token generation
5. Log:
   - tokens/sec
   - GPU temp
   - RAM usage

Record:

```
Model:
Quant:
Ctx:
Tokens/sec:
Temp (avg):
Swap used:
```

---

# 🛡 Security Notes

If exposing beyond LAN:

- Use reverse proxy (nginx)
- Add firewall rule
- Bind to localhost if internal-only:
  ```
  --host 127.0.0.1
  ```

Never expose raw port 8080 to the internet.

---

# 🧯 Common Failure Modes

| Error | Cause | Fix |
|-------|-------|------|
| OOM Killer | No swap | Enable 8GB swap |
| output.weight missing | Tied embeddings | Use older untied model |
| Illegal instruction | Wrong commit | Use pinned commit |
| CUDA not detected | GGML_CUDA not enabled | Rebuild |
| Throttling | Overheating | Improve cooling |

---

# 📌 Realistic Expectations

Jetson Nano is:
- Edge inference node
- Embedding server
- Research demonstrator
- Robotics co-processor

It is NOT:
- A multi-user LLM host
- A 7B+ model machine
- A training device

---

# 🎓 Research Value

This deployment demonstrates:

- Legacy CUDA constraint engineering
- Maxwell architecture optimization
- Embedded AI systems design
- Memory-constrained inference tuning
- Systemd-based model orchestration
- GPU profiling on edge hardware

It is a strong embedded-AI portfolio project when paired with:

- Benchmark logging
- Thermal characterization
- Power draw measurement
- Comparative CPU vs GPU tests
- Context scaling experiments

---

# ✅ Final Result

After reboot:

```
systemctl status llama-server
```

If active, your Jetson Nano now boots into:

**A GPU-accelerated, OpenAI-compatible, persistent LLM server optimized for CUDA 10.2 Maxwell architecture.**

---
