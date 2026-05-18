# I Built Jarvis in My Bedroom — A Fully Private, Edge-AI Voice Assistant That Lives on My Homelab

> *No cloud. No subscriptions. No one listening. Just four single-board computers, a microphone, and a whole lot of stubbornness.*

---

<!-- 📸 PHOTO SUGGESTION: Hero shot — wide angle of your desk/rack with all the hardware lit up. Raspberry Pis, the Jetson, the Orange Pi, cables, the whole beautiful mess. Make it atmospheric — dim room, LEDs, the glow of a terminal. -->

There's a specific kind of frustration that comes from being a developer who also cares deeply about privacy. You use voice assistants. You love the convenience. But you also know — really *know* — that every "Hey Alexa" and every "OK Google" is a round trip to someone else's datacenter, logged, analyzed, and stored indefinitely. You accept it because the alternative seemed impossibly hard.

It doesn't have to be.

Over the past several months I've been building what I internally call **Jarvis**: a fully local, privacy-first, edge-AI voice assistant that runs entirely on hardware I own, on a network I control, with models I chose. No cloud inference. No subscription fees. No terms of service that change without notice. Just my voice, my hardware, and a surprisingly capable AI that responds in natural language and can actually control my home.

This post is about *why* I built it, *how* it all fits together at a high level, and why I think this kind of homelab project is worth your time even if you never deploy anything exactly like it. A full step-by-step tutorial series is coming — consider this the "big picture" piece you'll want to read first.

---

## The Itch That Wouldn't Go Away

It started, as these things often do, with a small annoyance.

I was living with a commercial smart speaker and it was fine — until it wasn't. The wake word false-positive rate was maddening. The latency on complex queries was embarrassing. And one day, reading through a product's updated privacy policy, I realized I genuinely didn't know what was happening to my voice data. The company's answer was essentially: *trust us.*

I didn't want to trust them. I wanted to build something I could understand end-to-end.

Around the same time I'd been tinkering with local LLM inference. Models like Llama had gotten genuinely impressive at small sizes, especially with quantization. Whisper had made offline speech-to-text accurate enough to use daily. Text-to-speech had quietly caught up to commercial quality. The pieces were all there. Someone just needed to assemble them into something that actually worked as a product — something you could shout across the room at and get a useful answer back in under two seconds.

That someone turned out to be me.

---

## The Hardware Stack — Four Computers That Became One Brain

<!-- 📸 PHOTO SUGGESTION: Individual glamour shots of each board — the two Pis, the Orange Pi, and the Jetson — maybe laid out on a table before assembly, or mounted in their final positions. -->

The first thing I had to decide was: what hardware? And the answer ended up being a small fleet of single-board computers, each with a distinct role.

<!-- 📊 DIAGRAM SUGGESTION: Insert the homelab network diagram here (the one with the local 192.168.1.0/24 network, the switch, and the Tailscale overlay). This is the perfect place for it — right after introducing the hardware. -->

**Raspberry Pi 1 — the Server.** This is my general-purpose server node. It handles file sharing, DNS, and acts as the coordination point for services that don't need serious compute. Lean, reliable, always on.

**Raspberry Pi 2 — the Client.** My secondary Pi acts as a thin client and handles satellite services. It's part of the network fabric but doesn't carry heavy workloads.

**Orange Pi 3B — the Watchtower.** This one has a dedicated purpose: monitoring. It runs my entire observability stack — metrics collection, dashboards, alerts. The Orange Pi 3B punches well above its weight class for this kind of workload, and dedicating a node entirely to monitoring means I always have visibility into the system's health even when other nodes are thrashing under load.

**NVIDIA Jetson Orin Nano — the Brain.** This is the star of the show. The Jetson is where the actual AI inference happens. It has a proper GPU — not a desktop-class GPU, but a capable embedded one with unified memory — and it runs everything that requires real compute: speech recognition, language model inference, and text-to-speech synthesis. Choosing the Jetson over, say, a Pi 5 was a deliberate call: I wanted real GPU acceleration, and the Jetson's CUDA cores and TensorRT support make a night-and-day difference on transformer workloads.

All four nodes connect through a single 8-port Gigabit switch on a dedicated local subnet at `192.168.1.0/24`. Fast, low-latency, wired. No Wi-Fi in the critical path.

---

## The Network Layer — Zero Trust, Everywhere

Here's where things get interesting from a networking perspective — and where a lot of homelab projects get lazy and pay for it later.

I didn't want to open ports on my router. Port-forwarding is a security disaster waiting to happen, and managing firewall rules manually is the kind of thing that looks fine until it suddenly, catastrophically, isn't. Instead, I went with **Tailscale** as a Zero Trust overlay network.

Tailscale gives each of my nodes a stable private IP in the `100.x.x.x` CGNAT range, reachable from anywhere in the world through encrypted peer-to-peer tunnels — no port forwarding required, no exposed public IP, no NAT traversal headaches. Each node authenticates with its own identity, and access between nodes is controlled by **Tailscale ACLs** — policy-as-code that I can read, version-control, and audit.

The result: `pi-server` at `100.1.1.1`, `pi-client` at `100.1.1.2`, `orange-pi` at `100.1.1.3`, `jetson-nano` at `100.1.1.4`. My external laptop connects to any of them as naturally as if they were on the same desk. The principle behind all of it: **Never Trust, Always Verify.** Every connection is authenticated. Every ACL is explicit. There's no implicit trust just because something is "inside the network."

This matters more than people think. When you're running local AI inference on hardware you care about, having a proper network security model isn't paranoia — it's just good engineering.

<!-- 📊 DIAGRAM SUGGESTION: The Tailscale network diagram (already in your post assets) fits perfectly here, after explaining the Zero Trust philosophy. Readers will immediately understand why the overlay exists. -->

---

## The Voice Pipeline — From "Hey Jarvis" to an Actual Answer

Now for the part that makes this project special: the actual voice assistant architecture. This is the piece I'm most proud of, and it's considerably more sophisticated than it might look from the outside.

<!-- 📊 DIAGRAM SUGGESTION: Insert the Edge-AI Voice Assistant architecture diagram here. This is the centerpiece of the post — give it full width and maybe a caption explaining what the numbered steps represent. -->

The pipeline has two physical actors: a **Remote Satellite Node** (the Orange Pi or an ESP32) and the **Central AI Hub** (the Jetson). Let me walk you through what happens when you say "Hey Jarvis, turn off the bedroom lights."

### Step 1 — Wake Word Detection, Locally

An INMP441 I2S microphone captures audio continuously. On the satellite node, a small local model called **openWakeWord** runs all the time, listening for the trigger phrase. This model is tiny and runs comfortably on the satellite node's CPU — it doesn't need the Jetson. When it hears the wake word, it fires. When it doesn't, it just loops silently.

This is a critical design choice: wake word detection never leaves the device. No audio is ever streamed before you've explicitly triggered the system. The microphone is always on, but nothing is ever sent anywhere until you say the magic words.

### Step 2 — Audio Capture and Wyoming Satellite

Once the wake word fires, the **Wyoming Satellite Service** kicks in. Wyoming is Home Assistant's open protocol for satellite voice nodes — it handles the details of grabbing the audio stream and forwarding it intelligently. Think of it as the plumbing that connects the microphone to the brain.

### Step 3 — Speech-to-Text via Faster-Whisper TRT

The audio stream travels over TCP to the Jetson, where **Faster-Whisper TRT** is waiting for it. This is a TensorRT-optimized version of OpenAI's Whisper model — GPU-accelerated, running fast enough that transcription feels nearly instant. The Jetson's CUDA cores earn their keep here.

The output is text. Clean, accurate, fast.

### Step 4 — Language Model Inference with Ollama

The transcribed text goes to **Ollama**, running a **Llama 3.2 3B model in 4-bit quantization**. Four-bit quantization is one of the more quietly impressive developments in the open-source AI world: it dramatically reduces memory footprint with acceptable quality loss, letting a model that would normally require 6-8GB of RAM run comfortably in 2-3GB. On the Jetson's unified memory architecture, this matters enormously.

The LLM understands what you asked and responds with either a natural language answer or — and this is where it gets smart — a **tool call**. If you asked about the lights, it knows to call the home automation system rather than just talking about it.

### Step 5 — Home Assistant + n8n Automation

The tool call from the LLM goes to **Home Assistant**, which is the orchestrator layer of the entire system. Home Assistant handles device state, integrations, and automation rules. But for complex multi-step automations — "turn off the lights, lock the doors, and set the thermostat to 68 before I go to sleep" — it hands off to **n8n**, a self-hosted workflow automation tool that lets me build arbitrarily complex chains of actions through a visual editor.

The bridge between the LLM and these systems is an **MCP Server** — a Model Context Protocol server running on the Jetson that exposes home automation capabilities as structured tools the LLM can call. This is what makes Jarvis feel like an *agent* rather than a chatbot. It doesn't just answer questions. It *does things*.

### Step 6 — Text-to-Speech via Piper

The final step: whatever the LLM says back gets synthesized into speech by **Piper**, a fast, high-quality offline TTS system. The audio streams back to the satellite node and plays through the USB speaker. The whole round trip — from the moment you finish speaking to the moment Jarvis responds — is typically under two seconds.

---

## The Monitoring Stack — Because Blind Systems Fail Silently

<!-- 📸 PHOTO SUGGESTION: Screenshot of your monitoring dashboards — Grafana or whatever you're running on the Orange Pi. Show metrics for all four nodes side by side. This is genuinely cool to see. -->

One of the decisions I'm most glad I made early: dedicating an entire node — the Orange Pi 3B — to monitoring. Running your observability stack on the same hardware that you're trying to observe is a footgun. When the Jetson is running hot under an LLM inference load, the last thing you want is your monitoring stack competing for resources.

The monitoring layer keeps an eye on all four nodes simultaneously: CPU and memory utilization, GPU utilization on the Jetson, disk I/O, network throughput, container health for every Docker service, and end-to-end pipeline latency. When something goes wrong — when a container crashes, when inference time spikes, when disk fills up — I know immediately, before it becomes a user-facing problem.

I run the stack containerized, because isolated deployments on embedded hardware are dramatically easier to maintain and update. Docker Compose handles the orchestration locally; Tailscale handles the networking between the monitoring node and the things it's monitoring.

The goal was simple: I never want to be in a position where I'm debugging Jarvis by SSHing into nodes and running `top`. The dashboards tell the story. The alerts catch it before I need to look.

---

## Home Assistant — The Connective Tissue

It's worth saying more about Home Assistant, because it's doing a lot of the invisible work in this system.

Home Assistant is the reason Jarvis isn't just a fancy voice transcription service. It's what makes "turn off the lights" actually turn off the lights. It integrates with hundreds of smart home protocols and devices — Zigbee, Z-Wave, Matter, Wi-Fi devices, MQTT sensors — and it exposes all of them through a unified API. That API is what the MCP Server wraps and presents to the LLM as callable tools.

But Home Assistant does more than device control. It maintains the state of everything — what's on, what's off, what temperature things are, whether anyone's home. That state is what the LLM queries when you ask "are the bedroom lights on?" It's also what drives automation rules: time-of-day logic, presence detection, multi-device scenes.

Running Home Assistant locally, on hardware I control, means it also never phones home. My device states, my presence patterns, my automations — none of that leaves my network. Combined with Tailscale for remote access, I get the full Home Assistant experience from anywhere in the world, with zero reliance on their cloud services.

---

## Why This Is Actually Worth Doing

I've given you the architecture. Let me give you the argument.

The commercial AI assistant market has converged on a model that's fundamentally at odds with your interests: always-on microphones, cloud-side processing, opaque data policies, and a revenue model that depends on knowing as much about you as possible. These products are genuinely impressive. They're also not yours.

What I've built is meaningfully different. The wake word never leaves the room. The audio is never stored. The LLM runs on my hardware and produces no logs I don't control. The entire system can be audited because I assembled it myself from open-source components. And when a company changes its privacy policy or discontinues a service, nothing about my setup changes.

There's also a deeper satisfaction here that's hard to articulate cleanly. When Jarvis understands a complex request and executes it correctly — when it reasons through "turn off everything except the bedroom, set the thermostat lower, and remind me to take my medication in an hour" — the accomplishment feels different than it would if I'd plugged in a commercial product. I know how it works. I know why it works. I can make it do new things.

That's worth something.

---

## What's Coming Next

<!-- 📸 PHOTO SUGGESTION: Close-up of the Jetson Nano board — the GPU heatsink, the ports. Or a shot of the microphone mounted somewhere in your home. Something that grounds the project in physical reality. -->

This post is the "why and what" — the vision piece. The "how" is a full tutorial series I'm writing now, covering each layer of the stack in depth:

- **Part 1:** Hardware selection, assembly, and the initial network setup
- **Part 2:** Tailscale Zero Trust configuration and ACL policies
- **Part 3:** Setting up the Wyoming Satellite on the Orange Pi / ESP32
- **Part 4:** Deploying the AI stack on the Jetson — Faster-Whisper TRT, Ollama, and Piper
- **Part 5:** Home Assistant + n8n integration and the MCP bridge
- **Part 6:** The monitoring stack — metrics, dashboards, and alerting across all nodes
- **Part 7:** Performance tuning — NVMe swap, MAXN power mode, 4-bit quantization, and unified memory management

Each part will be detailed enough to reproduce. The goal isn't to show off — it's to give you a complete path from zero to a working system.

---

## The Bottom Line

Four single-board computers. A microphone and a speaker. A suite of open-source models and tools assembled with care. The result: a voice assistant that's faster than you'd expect, more capable than you'd imagine, and entirely, verifiably *yours*.

Jarvis isn't perfect. There are latency spikes. There are wake word misses. There are things commercial assistants do better. But when I ask it a question and it answers — correctly, instantly, using inference that ran three feet away from me on hardware I own — it feels like a small proof that the future of AI doesn't have to be something you rent from a corporation.

It can be something you build.

---

*Got questions about the architecture or the hardware choices? Drop them in the comments. And if you want to follow the tutorial series as it publishes, subscribe to the newsletter — I'll only email you when there's a new part.*

---

**Tags:** homelab, AI, edge computing, privacy, Home Assistant, Raspberry Pi, NVIDIA Jetson, Tailscale, voice assistant, self-hosted, LLM, open source
