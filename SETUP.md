# annoNAS setup guide
> Orange Pi 3B setup for AI, GPU, and case builder tools

---

### 🧰 **System Overview**

* **Device:** Orange Pi 3B
* **OS:** Orange Pi OS 1.0.8 Jammy (Ubuntu 22.04 server, no GUI)
* **Main goals:**

  * Headless server setup
  * Activate GPU (Mali G52, via Panfrost)
  * Test with `glmark2-es2-drm`
  * Explore RKNN toolkit for NPU
  * Fix Wi-Fi disconnections
  * Run case builder tools (DXF, Illustrator/Inkscape issues)

---

## ⚙️ Step-by-Step Setup

### 🔧 1. **Basic Ubuntu Server Setup**

* Download and flash **Orange Pi OS Jammy Server 1.0.8** to SD card
* Boot your Orange Pi 3B
* Log in via SSH or serial (default username: `orangepi`, then set your own)

### 👤 2. **Change Root Username to Your Own**

```bash
sudo usermod -l wanghley orangepi
sudo groupmod -n wanghley orangepi
sudo usermod -d /home/wanghley -m wanghley
```

> If necessary, fix file permissions:

```bash
sudo chown -R wanghley:wanghley /home/wanghley
```

---

### 🌐 3. **Fix Wi-Fi Disconnections**

If your Orange Pi Wi-Fi keeps disconnecting:

* Open NetworkManager config:

```bash
sudo nano /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
```

* Change:

```ini
wifi.powersave = 3
```

to

```ini
wifi.powersave = 2
```

* Then:

```bash
sudo systemctl restart NetworkManager
```

---

### 💾 4. **Install RKNN Toolkit (for NPU)**

You used this script based on Pelochus's repo:

```bash
#!/bin/bash

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root!"
  exit
fi

echo "Installing pip dependencies for ARM64..."
pip install ./rknn-toolkit-lite2/packages/rknn_toolkit_lite2-2.3.0-cp310-cp310-manylinux_2_17_aarch64.manylinux2014_aarch64.whl
pip install -r ./rknn-toolkit2/packages/arm64/arm64_requirements_cp310.txt

echo "Installing RKNN NPU API..."
cp ./rknpu2/runtime/Linux/librknn_api.a /usr/lib/
```

---

### 🧠 5. **Test NPU Acceleration**

Use `rknn-toolkit-lite2` with example models from [Pelochus's repo](https://github.com/Pelochus/ezrknn-toolkit2) or your own.

---

### 🎮 6. **GPU Setup (Mali G52 via Panfrost)**

#### 🛑 You encountered:

```bash
modprobe: FATAL: Module panfrost not found in directory /lib/modules/5.10.160-rockchip-rk356x
```

#### ✅ So here’s what you **should do:**

1. **Check Kernel Version**

```bash
uname -r
```

> You're using `5.10.160-rockchip-rk356x`, which **may not include Panfrost** module by default.

2. **Try Updating Modules**

```bash
sudo apt update
sudo apt install linux-modules-extra-$(uname -r)
```

3. **If not available**, build kernel with Panfrost manually or switch to Armbian (which may have Panfrost support out-of-the-box).

---

### 🔍 7. **Test GPU with DRM**

Even if GPU isn't working yet, try:

```bash
sudo glmark2-es2-drm
```

Expected output if GPU **works**:

```
GL_RENDERER: Mali-G52
```

If you see `llvmpipe`, it means software rendering is being used (no GPU accel yet).

---

### 🧰 8. **Case Builder/GUI Issues**

You tried to run [SBC Case Builder](https://github.com/hominoids/SBC_Case_Builder) and got DXF errors:

* ⚠️ Warnings: Unsupported `SPLINE`, `HATCH` in DXF
* Recommended:

  * In Illustrator: **Expand all paths**, convert SPLINEs to **straight lines or polylines**
  * In `.dxf` export: Choose **AutoCAD R14** or **2000** version (older)
  * Avoid effects like `HATCH`, gradients, fills

---

### 🖨️ 9. **Illustrator DXF Export Fix**

* **Select all paths**
* Go to: `Object > Path > Simplify` or `Object > Expand`
* Save As > DXF

  * Format: **AutoCAD 2000**
  * Units: mm
  * Ensure “Explode text to outlines” is **enabled**

---

### 🧱 10. **(Optional) Local Server Setup with RAID and Storage**

As part of your AI + Storage server plan:

* Install tools like:

```bash
sudo apt install mdadm smartmontools htop
```

* Setup RAID (e.g., RAID1 or 5) with:

```bash
sudo mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/sdX /dev/sdY
```

---

## ✅ Final Checklist

| Feature          | Status                | Notes                                             |
| ---------------- | --------------------- | ------------------------------------------------- |
| Ubuntu Server    | ✅ Installed           | Orange Pi OS 1.0.8 Jammy                          |
| Wi-Fi            | ✅ Fixed               | Set power save to `2`                             |
| RKNN Toolkit     | ✅ Installed           | Using `rknn-toolkit-lite2`                        |
| NPU              | ⚠️ Check with model   | No direct test result mentioned                   |
| GPU (Mali G52)   | ❌ Not active yet      | Panfrost module missing from kernel               |
| GPU Test         | ✅ glmark2 runs        | But uses software renderer (llvmpipe)             |
| Username         | ✅ Changed to wanghley | Used `usermod` and `groupmod`                     |
| Case Builder GUI | ⚠️ DXF issues         | Remove splines/hatch in Illustrator before export |
