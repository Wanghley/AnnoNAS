# Building Jarvis: The Complete Hardware & Software Tutorial

### A fully local, privacy-first Edge-AI Voice Assistant on a four-node homelab cluster

*By Wanghley Soares Martins — Duke University*

---

> **What you will build:** A voice-activated AI assistant that runs entirely on local hardware — no cloud services, no subscriptions, no data leaving your network. It listens for a wake word, transcribes your speech on a GPU-accelerated edge device, reasons through your request with a local LLM, executes home automations, and speaks back — in under two seconds.

---

## Table of Contents

1. [Prerequisites & Skill Level](#1-prerequisites--skill-level)
2. [Complete Bill of Materials](#2-complete-bill-of-materials)
3. [3D Printing Components](#3-3d-printing-components)
4. [Physical Assembly & Wiring](#4-physical-assembly--wiring)
5. [Operating System Installation](#5-operating-system-installation)
6. [Network Layer — Tailscale Zero Trust](#6-network-layer--tailscale-zero-trust)
7. [Containerization Strategy](#7-containerization-strategy)
8. [Part A — The AI Inference Stack (Jetson)](#part-a--the-ai-inference-stack-jetson)
9. [Part B — The Voice Satellite (Orange Pi / ESP32)](#part-b--the-voice-satellite-orange-pi--esp32)
10. [Part C — Home Assistant](#part-c--home-assistant)
11. [Part D — n8n Automation Engine](#part-d--n8n-automation-engine)
12. [Part E — The MCP Bridge](#part-e--the-mcp-bridge)
13. [Part F — Monitoring Stack](#part-f--monitoring-stack)
14. [Part G — Performance Tuning](#part-g--performance-tuning)
15. [Wiring Home Assistant to the AI Pipeline](#15-wiring-home-assistant-to-the-ai-pipeline)
16. [Troubleshooting Reference](#16-troubleshooting-reference)

---

## 1. Prerequisites & Skill Level

This tutorial is written for readers comfortable with Linux command-line basics, Docker, and home networking. You do not need prior experience with AI/ML frameworks or embedded systems, but you should be comfortable with:

- SSH into Linux machines
- Editing configuration files in a terminal (`nano`, `vim`)
- Basic Docker and Docker Compose syntax
- Reading a wiring diagram / pinout

Estimated build time: **2–3 weekends** for a first-time builder, depending on your familiarity with the stack. Individual sections can be completed and tested independently.

---

## 2. Complete Bill of Materials

### 2.1 Core Compute Nodes

| Component | Model | Qty | Approx. Price | Notes |
|---|---|---|---|---|
| SBC — Server | Raspberry Pi 4 Model B 4GB | 1 | ~$55 | pi-server node |
| SBC — Client | Raspberry Pi 4 Model B 4GB | 1 | ~$55 | pi-client / satellite node |
| SBC — Monitoring | Orange Pi 3B 4GB | 1 | ~$45 | Rockchip RK3566, dedicated observability |
| AI Compute | NVIDIA Jetson Orin Nano 8GB Dev Kit | 1 | ~$249 | Includes carrier board, heatsink, fan |

> **Why the Jetson Orin Nano?** It ships with 1024 CUDA cores, 32 Tensor Cores, 8GB of unified LPDDR5 RAM shared between CPU and GPU, and native TensorRT support. It is the lowest-cost NVIDIA platform capable of running a 3B parameter LLM at real-time inference speeds.

### 2.2 Storage

| Component | Model | Qty | Approx. Price | Notes |
|---|---|---|---|---|
| MicroSD — Pi x2 | Samsung Endurance Pro 32GB | 2 | ~$10 ea | Use Endurance-class for longevity |
| MicroSD — Orange Pi | Samsung Endurance Pro 32GB | 1 | ~$10 | |
| NVMe SSD — Jetson | Samsung 970 EVO Plus 500GB | 1 | ~$65 | For model storage + 16GB swap |
| M.2 to NVMe adapter | Waveshare M.2 NVMe SSD Expansion for Jetson | 1 | ~$20 | Mounts in Jetson carrier board M.2 slot |

### 2.3 Networking

| Component | Model | Qty | Approx. Price | Notes |
|---|---|---|---|---|
| Gigabit Switch | TP-Link TL-SG108 8-Port | 1 | ~$22 | Unmanaged; silent fanless operation |
| Ethernet Cable Cat6 | 0.5m patch cables | 6 | ~$3 ea | Short runs — avoid cable clutter |
| Router | Any existing home router | — | — | Only needs internet access for Tailscale |

### 2.4 Audio Hardware

| Component | Model | Qty | Approx. Price | Notes |
|---|---|---|---|---|
| I2S MEMS Microphone | INMP441 breakout module | 1 | ~$8 | Ultra-low noise, 24-bit, up to 15kHz |
| USB Speaker | Anker PowerConf S330 or generic USB mono speaker | 1 | ~$15–40 | USB simplifies audio routing |
| Jumper wires F-F | Generic 20cm female-to-female | 6 | ~$3 | GPIO connection to INMP441 |
| 2.54mm JST connector set | Optional — for a clean removable mic connection | 1 | ~$8 | |

> **Alternative mic option:** The **ReSpeaker 2-Mic Pi HAT** is a plug-and-play I2S mic HAT for the Raspberry Pi that eliminates manual GPIO wiring. More expensive (~$20) but faster to set up.

### 2.5 Power

| Component | Model | Qty | Approx. Price | Notes |
|---|---|---|---|---|
| Pi Power Supply | Official Raspberry Pi USB-C 5V/3A | 2 | ~$12 ea | |
| Orange Pi Power | 5V/4A barrel jack adapter | 1 | ~$10 | Check Orange Pi 3B spec for barrel size (5.5/2.1mm) |
| Jetson Power | Included with Dev Kit (19V/40W) | 1 | — | Do not substitute |
| Power Strip | 6-outlet, surge protected | 1 | ~$18 | All nodes + switch in one strip |

### 2.6 3D Printing Materials & Accessories

| Component | Qty | Notes |
|---|---|---|
| PLA+ filament (black or grey) | ~500g | Enclosures for Pis and Orange Pi |
| PETG filament | ~300g | Jetson enclosure — better thermal tolerance |
| M2.5 × 6mm standoffs (brass) | 20 | For mounting boards inside printed cases |
| M2.5 × 4mm screws | 20 | |
| M3 × 8mm hex bolts | 12 | Cluster rack assembly |
| M3 hex nuts | 12 | |
| M2 × 8mm self-tapping screws | 8 | Securing PCBs |
| Velcro cable ties | 1 pack | Cable management |
| Foam adhesive pads 3M | 4 | Anti-vibration feet |

**Total estimated build cost: ~$620–680 USD**

---

## 3. 3D Printing Components

All print files referenced below are available on **Printables.com** and **Thingiverse**. Where no direct link is provided, search the model name in the platform's search bar.

### 3.1 Recommended Slicer Settings (General)

| Parameter | PLA+ Parts | PETG Parts |
|---|---|---|
| Layer height | 0.2mm | 0.2mm |
| Infill | 20% Gyroid | 25% Gyroid |
| Perimeters / walls | 3 | 4 |
| Top/bottom layers | 5 | 5 |
| Print speed | 50–60 mm/s | 40–50 mm/s |
| Nozzle temp | 215°C | 235°C |
| Bed temp | 60°C | 80°C |
| Supports | Only where needed | Only where needed |
| Cooling | 100% fan | 50% fan |

### 3.2 Raspberry Pi 4 Enclosure (×2)

**Recommended design:** *"Raspberry Pi 4 Case with Fan and GPIO Access"* — search **Printables #117483** or **Thingiverse #3723561**

**Print in PLA+.** Two shells (top + bottom) + optional fan duct.

**Modifications to make:**
- Add a 2mm channel along the side wall for GPIO wire egress (if connecting the INMP441 to the pi-client unit). Modify the STL in your slicer using the "cut" function to open a slot at GPIO header height on the case side.
- Print the **open-GPIO-access** variant if available — this leaves the 40-pin header exposed.

**Hardware to install after printing:**
- 4× M2.5 × 6mm brass standoffs pressed into case floor
- 4× M2.5 screws from underside to secure the Pi

**Print time:** ~3h per case

<!-- 📸 PHOTO SUGGESTION: Side-by-side of the two Pi cases printed and assembled, with the GPIO slot modification visible on the pi-client case. -->

### 3.3 Orange Pi 3B Enclosure

**Recommended design:** *"Orange Pi 3B Case"* — search **Printables** for "Orange Pi 3B enclosure" — several community designs available, choose one with ventilation slots on top.

**Print in PLA+.** Orange Pi 3B runs warmer than a Pi 4 under monitoring load, so make sure your chosen case has side or top ventilation.

**Modifications to make:**
- If your design doesn't include a status LED window, add a 3mm round hole on the front face aligned with the board's power LED.
- Consider printing the case with a **removable SD card access slot** on the side — helpful if you ever need to re-flash.

**Print time:** ~4h

### 3.4 NVIDIA Jetson Orin Nano Enclosure

**Recommended design:** *"Jetson Orin Nano Developer Kit Case"* — search **Printables** for "Jetson Orin Nano case" — Waveshare and community designs both exist.

**Print in PETG.** The Jetson under sustained AI inference load will heat significantly. PETG's glass-transition temperature (~80°C) gives you a safety margin that PLA+ (~60°C) does not.

**Key requirements for this enclosure:**
- Full clearance for the existing heatsink + fan assembly (it is tall — about 45mm above the board)
- M.2 slot access port on the underside for the NVMe drive
- Ventilation cutouts on all four sides
- Exposed 40-pin GPIO header (not needed for Jarvis but useful for future expansion)

**Print time:** ~6h (larger footprint, thicker walls)

**Assembly note:** The Jetson Dev Kit uses **M2.5 mounting holes** at its four corners. Use 8mm standoffs and secure the board before closing the case. Check that the fan power connector clears the case roof by at least 5mm.

<!-- 📸 PHOTO SUGGESTION: The Jetson in its PETG case with the NVMe SSD visible through the underside access port. -->

### 3.5 INMP441 Microphone Enclosure & Mount

This is the most custom print in the build. You have two options:

**Option A — Tabletop housing (recommended for a desk setup):**

Design a small cylindrical or rectangular enclosure roughly 40mm × 30mm × 20mm with:
- A 5mm diameter sound inlet hole on the top face centered over the mic capsule
- A cable egress channel on the back
- A flat weighted base (fills with 10mm of infill for mass) for stability

If you don't want to design from scratch: search **Printables** for *"INMP441 microphone housing"* — several parametric designs exist that you can scale to your preference.

**Option B — Wall-mount housing:**

For a room-installation approach, print a wedge-shaped wall mount that:
- Angles the mic upward at 15–20° toward speaking height
- Has a keyhole slot on the back for a standard wall screw
- Encloses the INMP441 board fully with a front grille pattern (hexagonal or circular cutouts) over the capsule

**Print in PLA+.** Print the mic housing with **5 perimeter walls** — mass helps dampen vibration noise.

**Assembly:**
1. Thread the jumper wires through the cable channel before inserting the INMP441 board.
2. Secure the board with a dab of hot glue or a single M2 screw through the PCB mounting hole if present.
3. Close the housing. No glue needed if the tolerances are good — a press-fit top is cleaner.

**Print time:** ~45min

### 3.6 Cluster Rack / Desktop Stand

For a clean desktop installation, print a **stacked SBC rack** that holds all four nodes in a vertical tower.

**Recommended design:** Search **Printables** for *"Raspberry Pi cluster rack"* — many designs support 2–5 boards in a stackable column. Choose one with:
- 50mm+ vertical spacing between tiers (needed for Jetson heatsink)
- Cable routing channels on the sides
- Ventilation openings on all faces

Alternatively, print individual desktop stands for each node and arrange them side by side.

**Material:** PLA+, 25% infill, 4 perimeter walls for rigidity.

**Assembly hardware:** M3 × 8mm hex bolts + M3 nuts to lock tiers together.

**Print time:** ~8–12h for a full four-tier rack

<!-- 📸 PHOTO SUGGESTION: The fully assembled four-node cluster in its rack, all cables dressed with Velcro ties, power strip underneath. This is the "hero hardware" shot for the tutorial. -->

---

## 4. Physical Assembly & Wiring

### 4.1 Network Infrastructure

1. Mount the 8-port switch in your desired location.
2. Run Cat6 patch cables from each SBC's Ethernet port to the switch. Label each cable at both ends with tape flags:
   - `pi-server` → Port 1
   - `pi-client` → Port 2
   - `orange-pi` → Port 3
   - `jetson-nano` → Port 4
3. Run one uplink cable from switch Port 8 to your router's LAN port.

### 4.2 INMP441 I2S Microphone Wiring (to Raspberry Pi 4)

The INMP441 connects to the Raspberry Pi's GPIO header via the I2S (Inter-IC Sound) bus. Use the following pinout:

```
INMP441 Pin → Raspberry Pi GPIO Header Pin
─────────────────────────────────────────────
VDD (3.3V)  → Pin 1   (3.3V Power)
GND         → Pin 6   (Ground)
SCK         → Pin 12  (GPIO 18 — PCM_CLK  / I2S Bit Clock)
WS          → Pin 35  (GPIO 19 — PCM_FS   / I2S LR Clock)
SD          → Pin 38  (GPIO 20 — PCM_DIN  / I2S Data In)
L/R         → Pin 6   (Ground → selects LEFT channel)
```

> **Pro tip:** Twist the SCK and WS wires together loosely. These are clock signals that can radiate noise — keeping them physically close reduces crosstalk.

**Verify continuity** with a multimeter in beep/continuity mode before powering on. A short on the 3.3V rail can damage the Pi.

<!-- 📸 PHOTO SUGGESTION: Close-up of the INMP441 wired to the Pi GPIO header, with labels on each jumper wire. Macro lens if possible — this pinout photo is one of the most referenced images in voice assistant tutorials. -->

### 4.3 NVMe SSD Installation in Jetson

1. Power off the Jetson completely.
2. Locate the M.2 Key M slot on the underside of the Jetson Orin Nano carrier board.
3. Insert the Samsung 970 EVO Plus at the correct angle (approximately 30°), then press down flat and secure with the M.2 retaining screw.
4. If using a Waveshare NVMe expansion board, follow its separate assembly instructions — it mounts on the carrier board's expansion header.

### 4.4 Power Wiring

Connect all power supplies before connecting the network. Power-sequence order doesn't technically matter for this cluster, but a clean boot order is:

1. Power on the switch first.
2. Power on `pi-server`.
3. Power on `orange-pi`.
4. Power on `jetson-nano`.
5. Power on `pi-client`.

This gives the server node a head start so services it hosts (DNS, shared config) are available when other nodes come up.

---

## 5. Operating System Installation

### 5.1 Raspberry Pi 1 & 2 — Raspberry Pi OS (64-bit)

1. Download **Raspberry Pi Imager** from `raspberrypi.com/software`.
2. Select: **Raspberry Pi OS Lite (64-bit)** — no desktop environment needed.
3. Before flashing, click the gear icon and configure:
   - Hostname: `pi-server` (or `pi-client` for the second Pi)
   - Enable SSH with password or public key
   - Set username (`jarvis`) and password
   - Configure Wi-Fi only if you need it during initial setup; switch to Ethernet afterward
4. Flash to MicroSD. Boot and SSH in: `ssh jarvis@pi-server.local`

**Initial setup on both Pis:**

```bash
# Update system
sudo apt update && sudo apt full-upgrade -y

# Install essentials
sudo apt install -y git curl wget vim htop docker.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Enable Docker
sudo systemctl enable docker && sudo systemctl start docker

# Set static IP (optional — Tailscale handles addressing, but useful for local network)
sudo nmcli con mod "Wired connection 1" ipv4.method manual \
  ipv4.addresses "192.168.1.10/24" ipv4.gateway "192.168.1.1" \
  ipv4.dns "1.1.1.1,8.8.8.8"
# Use .10 for pi-server, .11 for pi-client
```

### 5.2 Orange Pi 3B — Orange Pi OS (Debian)

1. Download the **Orange Pi OS (Debian Bookworm)** image from `orangepi.org` → Orange Pi 3B → Downloads.
2. Flash with **Balena Etcher** or `dd`.
3. Boot, SSH in (default credentials: `orangepi`/`orangepi`) — **change the password immediately.**

```bash
# Change password
passwd

# Update system
sudo apt update && sudo apt full-upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo systemctl enable docker

# Set hostname
sudo hostnamectl set-hostname orange-pi

# Static IP
sudo nmcli con mod "Wired connection 1" ipv4.method manual \
  ipv4.addresses "192.168.1.12/24" ipv4.gateway "192.168.1.1" \
  ipv4.dns "1.1.1.1"
```

### 5.3 NVIDIA Jetson Orin Nano — JetPack 6

The Jetson requires NVIDIA's JetPack SDK. **Do not flash Raspberry Pi OS or Ubuntu ARM — they will not include CUDA, TensorRT, or the Jetson-specific kernel.**

**Method A (Recommended) — SDK Manager on a Ubuntu host:**

1. On a separate Ubuntu 20.04/22.04 machine, install NVIDIA SDK Manager from `developer.nvidia.com/sdk-manager`.
2. Connect the Jetson to the host via USB-C (use the USB-C port on the carrier board, not the power barrel).
3. Put the Jetson into **Recovery Mode**: hold the Recovery button, press Reset, then release Recovery after 2 seconds.
4. In SDK Manager, select: Target → Jetson Orin Nano, JetPack 6.x.
5. Follow the wizard. SDK Manager will flash JetPack to the internal eMMC, then offer to install CUDA, TensorRT, and cuDNN. **Install all of them.**

**Method B — MicroSD pre-built image:**

NVIDIA provides a pre-built JetPack image for the Orin Nano. Flash with Balena Etcher. This is faster but installs components to MicroSD rather than eMMC — performance will be limited until you migrate to NVMe.

**Post-flash setup:**

```bash
# After first boot, SSH in
ssh jarvis@jetson-nano.local

# Verify CUDA is working
nvcc --version
# Expected output: Cuda compilation tools, release 12.x

# Verify TensorRT
python3 -c "import tensorrt; print(tensorrt.__version__)"

# Install Docker (JetPack includes nvidia-container-toolkit)
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
sudo systemctl enable docker

# Verify GPU is accessible from Docker
sudo docker run --rm --gpus all ubuntu nvidia-smi
# Should show Jetson GPU device

# Set hostname
sudo hostnamectl set-hostname jetson-nano
```

### 5.4 NVMe Setup on Jetson

```bash
# Identify the NVMe device
lsblk
# Look for nvme0n1

# Create a single partition
sudo fdisk /dev/nvme0n1
# Press: n → p → 1 → Enter → Enter → w

# Format
sudo mkfs.ext4 /dev/nvme0n1p1

# Create mount point and mount
sudo mkdir -p /mnt/nvme
sudo mount /dev/nvme0n1p1 /mnt/nvme
sudo chown -R $USER:$USER /mnt/nvme

# Get UUID for fstab
blkid /dev/nvme0n1p1
# Copy the UUID value

# Add to /etc/fstab
echo 'UUID=<YOUR-UUID> /mnt/nvme ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab

# Create directory structure on NVMe
mkdir -p /mnt/nvme/{ollama,whisper,piper,swap}

# Create 16GB swap file on NVMe
sudo fallocate -l 16G /mnt/nvme/swap/swapfile
sudo chmod 600 /mnt/nvme/swap/swapfile
sudo mkswap /mnt/nvme/swap/swapfile
sudo swapon /mnt/nvme/swap/swapfile

# Persist swap in fstab
echo '/mnt/nvme/swap/swapfile none swap sw,pri=10 0 0' | sudo tee -a /etc/fstab

# Verify swap is active
free -h
# Should show ~16G swap
```

---

## 6. Network Layer — Tailscale Zero Trust

Install Tailscale on **all four nodes** using the same Tailscale account.

### 6.1 Install Tailscale (run on each node)

```bash
# Universal installer
curl -fsSL https://tailscale.com/install.sh | sh

# Bring up Tailscale (authenticate via the URL it prints)
sudo tailscale up

# Verify your Tailscale IP
tailscale ip -4
```

After authenticating each node, they will appear in your Tailscale admin console at `login.tailscale.com`.

### 6.2 Assign Tags and Stable Hostnames

In the Tailscale admin console:

1. Go to **Machines** → click each node → **Edit route settings**.
2. Rename each device to match your target hostnames:
   - `pi-server`, `pi-client`, `orange-pi`, `jetson-nano`

### 6.3 Configure ACL Policy

In the Tailscale admin console → **Access controls**, paste the following policy:

```json
{
  "tagOwners": {
    "tag:jarvis-cluster": ["autogroup:owner"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:jarvis-cluster"],
      "dst": ["tag:jarvis-cluster:*"]
    },
    {
      "action": "accept",
      "src": ["autogroup:owner"],
      "dst": ["tag:jarvis-cluster:*"]
    }
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["autogroup:owner"],
      "dst": ["tag:jarvis-cluster"],
      "users": ["autogroup:nonroot", "root"]
    }
  ]
}
```

Then tag each machine:

```bash
# Run on each node — replace with the correct tag
sudo tailscale up --advertise-tags=tag:jarvis-cluster
```

### 6.4 Verify Connectivity

From any node:

```bash
# Ping all other nodes by their Tailscale hostnames
ping -c 3 pi-server
ping -c 3 pi-client
ping -c 3 orange-pi
ping -c 3 jetson-nano

# Confirm Tailscale IPs match your expected scheme
tailscale status
```

Your expected IP mapping:

| Hostname | Tailscale IP |
|---|---|
| pi-server | 100.1.1.1 |
| pi-client | 100.1.1.2 |
| orange-pi | 100.1.1.3 |
| jetson-nano | 100.1.1.4 |

> **Note:** Tailscale assigns IPs dynamically. The `100.1.1.x` addresses shown in this tutorial are illustrative. Your actual IPs will differ — note yours from `tailscale status` and substitute them wherever you see `100.1.1.x` in later steps.

---

## 7. Containerization Strategy

All services in Jarvis run in **Docker containers**, managed with **Docker Compose**. This gives you:

- Clean dependency isolation (no Python version conflicts between Whisper, Ollama, and Piper)
- One-command startup and restart
- Easy upgrades — pull new image, recreate container
- Consistent behavior across ARM64 (Pi, Orange Pi) and x86/CUDA (Jetson)

**Directory structure convention:**

```
/opt/jarvis/
├── jetson/          # AI inference stack — runs on jetson-nano
│   ├── docker-compose.yml
│   ├── whisper/
│   ├── ollama/      # Symlink → /mnt/nvme/ollama
│   └── piper/
├── satellite/       # Wyoming satellite — runs on pi-client
│   ├── docker-compose.yml
│   └── config/
├── homeassistant/   # HA + n8n + MCP — runs on pi-server
│   ├── docker-compose.yml
│   ├── config/
│   └── n8n/
└── monitoring/      # Prometheus + Grafana — runs on orange-pi
    ├── docker-compose.yml
    ├── prometheus.yml
    └── grafana/
```

Create this structure on the respective nodes:

```bash
# On jetson-nano
sudo mkdir -p /opt/jarvis/jetson/{whisper,piper}
sudo ln -s /mnt/nvme/ollama /opt/jarvis/jetson/ollama
sudo chown -R $USER:$USER /opt/jarvis

# On pi-client
sudo mkdir -p /opt/jarvis/satellite/config

# On pi-server
sudo mkdir -p /opt/jarvis/homeassistant/{config,n8n}

# On orange-pi
sudo mkdir -p /opt/jarvis/monitoring/grafana
```

---

## Part A — The AI Inference Stack (Jetson)

All commands in this section run **on the jetson-nano node** unless stated otherwise.

### A.1 Enable NVIDIA Container Runtime

JetPack 6 includes the NVIDIA Container Toolkit, but you need to configure Docker to use it as the default runtime:

```bash
# Configure Docker to use NVIDIA runtime by default
sudo nvidia-ctk runtime configure --runtime=docker --set-as-default
sudo systemctl restart docker

# Verify
docker info | grep -i runtime
# Should show: Default Runtime: nvidia
```

### A.2 Docker Compose — AI Stack

Create the compose file:

```bash
cat > /opt/jarvis/jetson/docker-compose.yml << 'EOF'
version: "3.8"

services:

  # ─── Speech-to-Text ───────────────────────────────────────────────────────
  wyoming-faster-whisper:
    image: rhasspy/wyoming-faster-whisper:latest
    container_name: whisper
    restart: unless-stopped
    ports:
      - "10300:10300"
    volumes:
      - /opt/jarvis/jetson/whisper:/data
    command: >
      --uri tcp://0.0.0.0:10300
      --model large-v3
      --language en
      --device cuda
      --compute-type float16
      --beam-size 5
      --data-dir /data
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  # ─── Large Language Model ─────────────────────────────────────────────────
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - /mnt/nvme/ollama:/root/.ollama
    environment:
      - OLLAMA_NUM_PARALLEL=1
      - OLLAMA_MAX_LOADED_MODELS=1
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  # ─── Text-to-Speech ───────────────────────────────────────────────────────
  wyoming-piper:
    image: rhasspy/wyoming-piper:latest
    container_name: piper
    restart: unless-stopped
    ports:
      - "10200:10200"
    volumes:
      - /opt/jarvis/jetson/piper:/data
    command: >
      --uri tcp://0.0.0.0:10200
      --piper /usr/local/bin/piper
      --voice en_US-lessac-medium
      --data-dir /data
      --download-dir /data

EOF
```

### A.3 Pull and Start the AI Stack

```bash
cd /opt/jarvis/jetson

# Pull all images (this takes a while — ~8GB total download)
docker compose pull

# Start everything
docker compose up -d

# Watch logs to confirm startup
docker compose logs -f
```

### A.4 Download the Language Model

```bash
# Pull into the running Ollama container
docker exec ollama ollama pull llama3.2:3b-instruct-q4_K_M

# Verify the model loaded
docker exec ollama ollama list
# Expected: llama3.2:3b-instruct-q4_K_M   ...   2.0 GB

# Test inference (should respond in a few seconds)
docker exec ollama ollama run llama3.2:3b-instruct-q4_K_M \
  "What is the capital of France? Answer in one sentence."
```

### A.5 Verify Whisper Is Working

```bash
# Check that Whisper is listening on port 10300
nc -zv localhost 10300
# Should say "Connection to localhost 10300 port [tcp/*] succeeded!"

# Check GPU is being used by containers
nvidia-smi
# Both whisper and ollama processes should appear under GPU processes
```

---

## Part B — The Voice Satellite (Orange Pi / Pi Client)

The satellite node is the hardware closest to the user — it runs the wake word engine and manages the microphone and speaker. This section runs **on pi-client**.

### B.1 Enable I2S for the INMP441

```bash
# Edit boot config
sudo nano /boot/config.txt

# Add these lines at the bottom:
dtparam=i2s=on
dtoverlay=i2s-mmap
```

Save and reboot: `sudo reboot`

After reboot, verify the I2S interface is available:

```bash
arecord -l
# Should list: card 0: sndrpisimplecar, device 0: ...
# If nothing shows, double-check your wiring against the pinout in Section 4.2
```

**Configure ALSA for the INMP441:**

```bash
sudo nano /etc/asound.conf
```

Paste:

```
pcm.dmic_hw {
  type hw
  card sndrpisimplecar
  channels 2
  format S32_LE
}

pcm.dmic_sv {
  type softvol
  slave.pcm dmic_hw
  control {
    name "Boost Capture Volume"
    card sndrpisimplecar
  }
  min_dB -3.0
  max_dB 30.0
}

pcm.!default {
  type asym
  capture.pcm "dmic_sv"
  playback.pcm "plughw:CARD=Speaker,DEV=0"
}
```

**Test mic capture:**

```bash
# Record 5 seconds of audio
arecord -D dmic_sv -r 16000 -c 1 -f S16_LE -d 5 test.wav

# Play it back (through USB speaker)
aplay test.wav
```

If you hear your voice clearly, the microphone is working.

### B.2 USB Speaker Setup

The USB speaker should appear automatically. Verify:

```bash
aplay -l
# Should list your USB speaker as a separate card

# Test playback
speaker-test -c 1 -t sine -f 440
```

### B.3 Docker Compose — Wyoming Satellite

```bash
cat > /opt/jarvis/satellite/docker-compose.yml << 'EOF'
version: "3.8"

services:

  # ─── Wake Word Detection ──────────────────────────────────────────────────
  wyoming-openwakeword:
    image: rhasspy/wyoming-openwakeword:latest
    container_name: openwakeword
    restart: unless-stopped
    ports:
      - "10400:10400"
    volumes:
      - /opt/jarvis/satellite/config/wakeword:/data
    command: >
      --uri tcp://0.0.0.0:10400
      --preload-model "hey_jarvis"
      --custom-model-dir /data
      --threshold 0.5
      --trigger-level 1

  # ─── Wyoming Satellite ────────────────────────────────────────────────────
  wyoming-satellite:
    image: rhasspy/wyoming-satellite:latest
    container_name: satellite
    restart: unless-stopped
    depends_on:
      - wyoming-openwakeword
    ports:
      - "10700:10700"
    devices:
      - /dev/snd:/dev/snd
    group_add:
      - audio
    command: >
      --name "Jarvis Bedroom"
      --uri tcp://0.0.0.0:10700
      --mic-command "arecord -D dmic_sv -r 16000 -c 1 -f S16_LE -t raw"
      --snd-command "aplay -D plughw:CARD=Speaker -r 22050 -c 1 -f S16_LE -t raw"
      --wake-uri tcp://localhost:10400
      --wake-word-name "hey_jarvis"
      --mic-noise-suppression 2
      --mic-auto-gain 5
      --debug

EOF

docker compose up -d
docker compose logs -f satellite
```

You should see the satellite connect and begin listening. When you say "Hey Jarvis" you will see the wake word detection event in the logs.

### B.4 Custom Wake Word (Optional)

The default `hey_jarvis` model is included with wyoming-openwakeword. To train a custom wake word:

1. Visit `colab.research.google.com` and use the **openWakeWord training notebook** (search: openWakeWord Google Colab).
2. Record 150–500 samples of your wake word using the provided recording script.
3. Train the model (runs in ~10 minutes on Colab).
4. Download the resulting `.tflite` file.
5. Place it in `/opt/jarvis/satellite/config/wakeword/` on pi-client.
6. Update the `--preload-model` flag in docker-compose.yml to match the filename.

---

## Part C — Home Assistant

Home Assistant is the orchestration layer. It runs **on pi-server** and manages all device integrations, state, and automation rules.

### C.1 Docker Compose — Home Assistant

```bash
cat > /opt/jarvis/homeassistant/docker-compose.yml << 'EOF'
version: "3.8"

services:

  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    network_mode: host
    volumes:
      - /opt/jarvis/homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=America/New_York

EOF

cd /opt/jarvis/homeassistant
docker compose up -d
```

Home Assistant will be available at `http://pi-server:8123` (or `http://100.1.1.1:8123` via Tailscale).

### C.2 Initial Home Assistant Configuration

1. Navigate to `http://pi-server:8123` in your browser.
2. Create your admin account.
3. Skip the device discovery step for now — you can add devices after the pipeline is working.

### C.3 Connect Satellite to Home Assistant

In Home Assistant:

1. Go to **Settings → Devices & Services → Add Integration**.
2. Search for **Wyoming Protocol**.
3. Add the satellite: `host = 100.1.1.2` (pi-client Tailscale IP), `port = 10700`.
4. Add the Whisper STT service: `host = 100.1.1.4` (jetson Tailscale IP), `port = 10300`.
5. Add the Piper TTS service: `host = 100.1.1.4`, `port = 10200`.

Home Assistant will now route voice from your satellite through Whisper (STT), then generate responses and route them through Piper (TTS) back to your speaker.

### C.4 Add Assist Pipeline

1. Go to **Settings → Voice Assistants**.
2. Click **Add assistant** → name it "Jarvis".
3. Set STT: Wyoming (Whisper on jetson-nano).
4. Set TTS: Wyoming (Piper on jetson-nano).
5. Set conversation agent: **Home Assistant** (built-in) for now — we'll swap this for Ollama in Part E.

Test it: say "Hey Jarvis, what time is it?" — you should get a spoken response.

---

## Part D — n8n Automation Engine

n8n handles complex multi-step automations that go beyond what Home Assistant's built-in scripting supports. It runs **on pi-server** alongside Home Assistant.

### D.1 Add n8n to the Home Assistant Compose File

```bash
# Append to /opt/jarvis/homeassistant/docker-compose.yml
cat >> /opt/jarvis/homeassistant/docker-compose.yml << 'EOF'

  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    volumes:
      - /opt/jarvis/homeassistant/n8n:/home/node/.n8n
    environment:
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://100.1.1.1:5678/
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=jarvis
      - N8N_BASIC_AUTH_PASSWORD=changeme_strong_password
      - GENERIC_TIMEZONE=America/New_York

EOF

docker compose up -d n8n
```

n8n will be available at `http://pi-server:5678`.

### D.2 Create Your First n8n Workflow

n8n workflows are triggered by webhooks. Create a "good night" routine:

1. Open n8n at `http://100.1.1.1:5678`.
2. Create a new workflow → add a **Webhook** node (POST method, path: `/goodnight`).
3. Add an **HTTP Request** node → POST to `http://homeassistant:8123/api/services/light/turn_off` with headers `Authorization: Bearer <YOUR_HA_TOKEN>` and body `{"entity_id": "light.all_lights"}`.
4. Chain additional nodes for thermostat, lock, etc.
5. Activate the workflow.

**Get a Home Assistant long-lived token:**
In HA → Profile → Long-lived Access Tokens → Create Token → copy it.

---

## Part E — The MCP Bridge

The MCP (Model Context Protocol) Server exposes Home Assistant capabilities as structured tools that Ollama can call. This is what makes Jarvis *agentic* — it can take real actions, not just answer questions.

### E.1 Deploy the HA-MCP Server

The `ha-bridge-mcp` project provides a ready-to-use MCP server for Home Assistant. It runs **on pi-server**:

```bash
# Clone the MCP bridge
cd /opt/jarvis/homeassistant
git clone https://github.com/tevonsb/homeassistant-mcp.git mcp-bridge
cd mcp-bridge

# Create config
cat > config.json << EOF
{
  "hass_url": "http://localhost:8123",
  "hass_token": "YOUR_LONG_LIVED_TOKEN_HERE",
  "port": 8080
}
EOF

# Build the Docker image
docker build -t ha-mcp-bridge .

# Run it
docker run -d \
  --name ha-mcp-bridge \
  --network host \
  -v $(pwd)/config.json:/app/config.json \
  --restart unless-stopped \
  ha-mcp-bridge
```

### E.2 Configure Ollama to Use MCP Tools

Update the Ollama container on the Jetson to know about the MCP bridge:

```bash
# On jetson-nano: create an Ollama modelfile with tool definitions
cat > /opt/jarvis/jetson/Modelfile << 'EOF'
FROM llama3.2:3b-instruct-q4_K_M

SYSTEM """
You are Jarvis, a home AI assistant. You have access to tools that control 
smart home devices, lights, thermostats, locks, and sensors. 

When a user asks you to do something in their home, use the appropriate tool.
When they ask a question that requires current device state, query the relevant
entities before answering.

Respond concisely. The user will hear your response through a speaker.
Avoid markdown formatting. Keep responses under 3 sentences unless detail
is explicitly requested.
"""
EOF

docker exec ollama ollama create jarvis -f /opt/jarvis/jetson/Modelfile
```

### E.3 Connect Ollama to the Assist Pipeline

In Home Assistant:

1. Install the **Ollama** integration: **Settings → Devices & Services → Add Integration → Ollama**.
2. Set host: `100.1.1.4` (Jetson Tailscale IP), port: `11434`.
3. Select model: `jarvis` (the custom Modelfile you created).
4. Go to **Voice Assistants → Jarvis pipeline → Conversation Agent** → switch from "Home Assistant" to "Ollama (jarvis)".

Your voice pipeline now uses the LLM as its brain.

---

## Part F — Monitoring Stack

All monitoring runs **on orange-pi**. This node observes all four cluster members.

### F.1 Deploy Node Exporter on All Nodes

Run this on **pi-server, pi-client, jetson-nano, AND orange-pi itself**:

```bash
docker run -d \
  --name node-exporter \
  --pid host \
  --network host \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  --restart unless-stopped \
  prom/node-exporter:latest \
  --path.procfs=/host/proc \
  --path.sysfs=/host/sys \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($$|/)'
```

Also deploy cAdvisor on all nodes (Docker container metrics):

```bash
docker run -d \
  --name cadvisor \
  --privileged \
  --network host \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  -v /dev/disk/:/dev/disk:ro \
  --restart unless-stopped \
  gcr.io/cadvisor/cadvisor:latest
```

**On jetson-nano only** — deploy GPU metrics exporter:

```bash
# Install jetson-stats for GPU telemetry
sudo pip3 install jetson-stats --break-system-packages

# Install the Prometheus exporter for jetson-stats
docker run -d \
  --name jetson-exporter \
  --privileged \
  --pid host \
  --network host \
  -v /run/jtop.sock:/run/jtop.sock \
  --restart unless-stopped \
  rbonghi/jetson-stats:latest \
  --port 9400
```

### F.2 Prometheus Configuration (on orange-pi)

```bash
cat > /opt/jarvis/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:

  - job_name: 'node-pi-server'
    static_configs:
      - targets: ['100.1.1.1:9100']
        labels:
          node: 'pi-server'

  - job_name: 'node-pi-client'
    static_configs:
      - targets: ['100.1.1.2:9100']
        labels:
          node: 'pi-client'

  - job_name: 'node-orange-pi'
    static_configs:
      - targets: ['100.1.1.3:9100']
        labels:
          node: 'orange-pi'

  - job_name: 'node-jetson'
    static_configs:
      - targets: ['100.1.1.4:9100']
        labels:
          node: 'jetson-nano'

  - job_name: 'cadvisor'
    static_configs:
      - targets:
          - '100.1.1.1:8080'
          - '100.1.1.2:8080'
          - '100.1.1.3:8080'
          - '100.1.1.4:8080'

  - job_name: 'jetson-gpu'
    static_configs:
      - targets: ['100.1.1.4:9400']
        labels:
          node: 'jetson-nano'

EOF
```

### F.3 Docker Compose — Monitoring Stack (on orange-pi)

```bash
cat > /opt/jarvis/monitoring/docker-compose.yml << 'EOF'
version: "3.8"

volumes:
  prometheus_data:
  grafana_data:

services:

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - /opt/jarvis/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - /opt/jarvis/monitoring/grafana:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=jarvis_grafana_pw
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_ANALYTICS_REPORTING_ENABLED=false

EOF

cd /opt/jarvis/monitoring
docker compose up -d
```

### F.4 Grafana Dashboard Setup

1. Open Grafana at `http://orange-pi:3000` (or `http://100.1.1.3:3000`).
2. Log in with `admin` / `jarvis_grafana_pw`.
3. Add Prometheus as a data source: **Connections → Data Sources → Add → Prometheus** → URL: `http://prometheus:9090`.
4. Import dashboards by ID:
   - **Node Exporter Full** → Dashboard ID `1860` (comprehensive system metrics)
   - **cAdvisor Exporter** → Dashboard ID `14282` (container-level metrics)
   - **NVIDIA Jetson Stats** → Dashboard ID `16808` (GPU, thermal, power)

For each import: **Dashboards → Import → Enter ID → Load → Select Prometheus datasource → Import**.

<!-- 📸 PHOTO SUGGESTION: Screenshot of your Grafana dashboard showing all four nodes in a single view — CPU rows for each node, GPU row for Jetson, container health indicators. This is the payoff image for the monitoring section. -->

---

## Part G — Performance Tuning

### G.1 Jetson — MAXN Power Mode

```bash
# On jetson-nano: switch to maximum performance mode
sudo nvpmodel -m 0

# Lock CPU and GPU to maximum frequencies
sudo jetson_clocks

# Verify current mode
sudo nvpmodel -q
# Expected: NV Power Mode: MAXN

# Make jetson_clocks persist across reboots
sudo jetson_clocks --store /etc/jetson_clocks.conf
sudo crontab -e
# Add: @reboot /usr/bin/jetson_clocks
```

### G.2 Jetson — Unified Memory Tuning

The Jetson Orin Nano's unified memory is shared between CPU and GPU. You want to ensure the LLM and Whisper get priority access:

```bash
# Set GPU memory growth (via environment variable in Ollama container)
# Add to Ollama service in docker-compose.yml:
environment:
  - OLLAMA_NUM_PARALLEL=1
  - OLLAMA_MAX_LOADED_MODELS=1
  - CUDA_VISIBLE_DEVICES=0

# Limit Whisper to float16 compute (already set in compose, but verify):
# --compute-type float16
# This halves memory usage vs float32 with minimal quality loss
```

### G.3 Model Quantization Selection Guide

| Model Format | RAM Usage | Quality | Best For |
|---|---|---|---|
| `q8_0` | ~3.8GB | Very good | If you have headroom |
| `q4_K_M` | ~2.0GB | Good | **Recommended — best balance on Jetson** |
| `q4_0` | ~1.8GB | Acceptable | If memory-constrained |
| `q2_K` | ~1.2GB | Degraded | Avoid for conversational use |

```bash
# To switch quantization level:
docker exec ollama ollama pull llama3.2:3b-instruct-q8_0
# Then update the modelfile and recreate the jarvis model
```

### G.4 Whisper Model Size Trade-offs

| Whisper Model | VRAM | Speed | Accuracy |
|---|---|---|---|
| `tiny.en` | ~150MB | Fastest | Lower |
| `base.en` | ~290MB | Fast | Acceptable |
| `small.en` | ~970MB | Good | Good |
| `medium.en` | ~3GB | Slower | Very good |
| `large-v3` | ~6GB | Slowest | **Best** |

On the Jetson Orin Nano 8GB with the LLM co-loaded, `medium.en` is often the best practical choice — lower latency than `large-v3` with minimal accuracy sacrifice. To switch:

```bash
# Edit docker-compose.yml on jetson — change --model flag:
# --model medium.en

docker compose up -d wyoming-faster-whisper
```

### G.5 Raspberry Pi — Memory Split

Both Pis are running headless (no display). Free up GPU memory:

```bash
# On both pi-server and pi-client
echo "gpu_mem=16" | sudo tee -a /boot/config.txt
sudo reboot
```

### G.6 Orange Pi — CPU Governor

```bash
# Set performance governor on Orange Pi for consistent monitoring latency
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Persist across reboots
sudo apt install -y cpufrequtils
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
```

---

## 15. Wiring Home Assistant to the AI Pipeline

At this point all components are running independently. This section connects them end-to-end and verifies the complete pipeline.

### End-to-End Test Checklist

```
[ ] 1. Say "Hey Jarvis" → satellite logs show wake word detected
[ ] 2. Speak a phrase → satellite streams audio to Whisper on Jetson
[ ] 3. Whisper transcribes → text visible in HA logs
[ ] 4. Ollama receives text → generates tool call or response
[ ] 5. If tool call → MCP bridge executes action in HA
[ ] 6. Piper synthesizes response → audio returns to satellite speaker
[ ] 7. Grafana shows spike in Jetson GPU utilization during steps 3–5
```

### Verify Pipeline Latency

```bash
# On jetson-nano — watch inference timing
docker logs -f ollama 2>&1 | grep "eval duration"
# Target: < 800ms for 3B model at q4_K_M on MAXN mode

# Check Whisper transcription time
docker logs -f whisper 2>&1 | grep "transcription"
# Target: < 500ms for sentences under 10 words on large-v3
```

### Common Integration Fix — Satellite Not Connecting to HA

If the satellite shows "connection refused" when trying to reach Home Assistant:

```bash
# Verify Wyoming integration is listening on pi-server
ss -tlnp | grep 10700
# If nothing, the satellite container isn't running

# Restart satellite
ssh jarvis@pi-client
cd /opt/jarvis/satellite
docker compose restart satellite

# Check HA firewall (should be open since we use host networking)
# If behind UFW on pi-server:
sudo ufw allow 10300/tcp
sudo ufw allow 10200/tcp
sudo ufw allow 10700/tcp
```

---

## 16. Troubleshooting Reference

### INMP441 — No Audio Capture

```bash
# Check I2S overlay loaded
dmesg | grep -i i2s
# Look for: "snd_rpi_simple_card: asoc-simple-card"

# List ALSA devices
arecord -l

# If device missing: verify wiring SCK/WS/SD pins
# Most common error: SD (data) wire disconnected or wrong GPIO
```

### Whisper — CUDA Out of Memory

```bash
# Check current GPU memory usage on Jetson
nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# Solution 1: Switch to smaller model (medium.en)
# Solution 2: Ensure Ollama isn't holding memory with a loaded model
docker exec ollama ollama list  # Check no model is "loaded"
# If loaded, send a dummy request to force unload timeout
```

### Ollama — Slow First Response

The first inference after startup loads the model weights from NVMe into unified memory. This takes 10–30 seconds but subsequent responses are fast. This is normal behavior — the model stays warm in memory after the first query.

```bash
# Pre-warm the model after container start
docker exec ollama ollama run jarvis "Hello" > /dev/null 2>&1 &
```

Add this to a startup script so Ollama is warm when you first speak to Jarvis.

### n8n Webhook Not Triggering

```bash
# Verify n8n is reachable from HA
curl -X POST http://100.1.1.1:5678/webhook/goodnight \
  -u jarvis:changeme_strong_password \
  -H "Content-Type: application/json" \
  -d '{"test": true}'

# If 404: workflow not active — activate it in the n8n UI
# If connection refused: check n8n container is running
docker ps | grep n8n
```

### Tailscale — Nodes Not Seeing Each Other

```bash
# Check Tailscale status
tailscale status

# If a node shows "offline": restart Tailscale on that node
sudo systemctl restart tailscaled
sudo tailscale up

# If ACLs are blocking: check admin console → Access Controls → Test
# Use the "Test" feature to simulate src → dst connections
```

### Grafana — No Data from Jetson

```bash
# Test node-exporter is reachable from orange-pi
curl http://100.1.1.4:9100/metrics | head -20

# If connection times out: firewall on Jetson may be blocking
# Jetson JetPack sometimes has UFW enabled
ssh jarvis@jetson-nano
sudo ufw status
sudo ufw allow 9100/tcp  # node-exporter
sudo ufw allow 9400/tcp  # jetson GPU exporter
sudo ufw allow 8080/tcp  # cadvisor
```

---

## Appendix: Quick Reference — Service Ports

| Service | Node | Port | Protocol |
|---|---|---|---|
| Home Assistant | pi-server | 8123 | HTTP |
| n8n | pi-server | 5678 | HTTP |
| MCP Bridge | pi-server | 8080 | HTTP |
| Ollama | jetson-nano | 11434 | HTTP |
| Whisper (Wyoming) | jetson-nano | 10300 | TCP |
| Piper (Wyoming) | jetson-nano | 10200 | TCP |
| Wyoming Satellite | pi-client | 10700 | TCP |
| openWakeWord | pi-client | 10400 | TCP |
| Prometheus | orange-pi | 9090 | HTTP |
| Grafana | orange-pi | 3000 | HTTP |
| Node Exporter | all nodes | 9100 | HTTP |
| cAdvisor | all nodes | 8080 | HTTP |
| Jetson GPU metrics | jetson-nano | 9400 | HTTP |

## Appendix: Startup Order

If you reboot the entire cluster, bring services up in this order to avoid dependency failures:

```
1. pi-server    →  Home Assistant, n8n, MCP Bridge
2. jetson-nano  →  Ollama, Whisper, Piper         (wait for Ollama to pre-warm: ~30s)
3. orange-pi    →  Prometheus, Grafana
4. pi-client    →  openWakeWord, Wyoming Satellite
```

A startup script using `ssh` commands on a timer can automate this sequence.

---

*Tutorial by Wanghley Soares Martins — Duke University*  
*Questions? Open an issue on the project repository or drop a comment on the blog post.*

**Tags:** edge-AI · homelab · tutorial · NVIDIA Jetson · Raspberry Pi · Home Assistant · Tailscale · Docker · Ollama · Whisper · Piper · 3D printing · self-hosted
