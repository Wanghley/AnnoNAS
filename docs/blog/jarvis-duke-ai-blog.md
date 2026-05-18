# Building Jarvis: A Case for Sovereign AI at the Edge

### What four single-board computers, an open-source LLM, and a zero-trust network taught me about the real cost of AI convenience

---

*By Wanghley Soares Martins — Duke University*

---

<!-- 
📸 HERO IMAGE SUGGESTION:
A clean, well-lit shot of all four nodes arranged together — the two Raspberry Pis, the Orange Pi 3B, and the NVIDIA Jetson Orin Nano — ideally with cables connected and indicator LEDs glowing. If you can photograph this on a clean surface (wood desk, lab bench, neutral background), it reads as polished and editorial. Pair it with a caption like: "The four-node homelab cluster powering Jarvis — roughly $400 in total hardware, zero recurring cloud costs."
-->

---

When we talk about artificial intelligence in everyday life, we tend to talk about access. Which model is the most capable? Which assistant answers fastest? Which platform has the best integrations? These are reasonable questions, and the industry has organized itself around answering them at scale — streaming inference from massive data centers, billed by the token, delivered through microphones that listen indefinitely.

What we talk about far less is the hidden architecture underneath that convenience: the data retention policies, the always-on audio capture, the inference logs, the feedback loops, the fact that your voice is — by default — someone else's training data.

This post is about a different approach. Over the past several months, I built **Jarvis**: a fully local, privacy-preserving, edge-AI voice assistant that runs on a four-node homelab cluster in my apartment. No cloud inference. No persistent audio storage. No opaque data policies. Every layer of the stack — from wake word detection to language model inference to text-to-speech synthesis — runs on hardware I own, on a network I control, under software I can audit.

The project surfaced something I didn't expect to find: that running capable AI locally, at the edge, is not just possible but increasingly *practical* — and that the engineering decisions required to do it well are among the most interesting in the field right now.

---

## The Problem With Convenience

There is a useful concept in security research called the **threat model** — a structured way of asking not just "is this system secure?" but "secure against what, for whom, and at what cost?" Voice assistants, examined through this lens, reveal a set of trade-offs that rarely appear in product marketing.

Commercial voice AI is architecturally centralized by design. When you speak to a smart speaker, your audio travels to a cloud endpoint, where it is transcribed by a proprietary speech-recognition model, interpreted by a proprietary language model, and returned as synthesized speech. Each of these steps involves a third party. Each generates logs. Each is subject to the data retention, access, and sharing policies of the provider — policies that can change, that have changed, and that are often written to favor the provider's interests over the user's.

This is not a conspiracy. It is an engineering and business reality. Cloud inference at scale is expensive, and the companies that provide it need to recoup costs somehow. The currency is almost always data.

The question I kept returning to was: what would the stack look like if the design constraint were reversed? Not "how do we make this fast and cheap for the provider?" but "how do we make this private, verifiable, and sovereign for the user?"

That question drove every decision in Jarvis.

---

## The Hardware: A Four-Node Cluster Under $400

<!-- 
📸 PHOTO SUGGESTION:
One photo per device, arranged as a 2×2 grid, each with a short caption. This works especially well for a technical blog — readers can immediately map the hardware to the architecture diagram.
  - Raspberry Pi 1: "pi-server — general services and coordination"
  - Raspberry Pi 2: "pi-client — satellite services"
  - Orange Pi 3B: "orange-pi — dedicated observability node"
  - NVIDIA Jetson Orin Nano: "jetson-nano — GPU-accelerated AI inference hub"
-->

The physical foundation of Jarvis is four single-board computers, each assigned a distinct role in the system architecture.

**Raspberry Pi 1 (Server)** handles general services: DNS, file coordination, and the glue-layer tasks that don't require heavy compute. It runs lean and stays always-on.

**Raspberry Pi 2 (Client)** participates in the network fabric and handles satellite services — the thin-client functions that connect peripheral devices to the cluster's core.

**Orange Pi 3B (Monitoring)** is dedicated entirely to observability. This was a deliberate architectural choice: running your monitoring stack on the same hardware you are observing is a category error. When the AI inference node is under sustained load, your monitoring system should not be competing for the same resources. The Orange Pi 3B runs the full metrics pipeline — system telemetry from all nodes, container health, latency tracking, alerts — completely independently. More on this later.

**NVIDIA Jetson Orin Nano (Compute)** is the cluster's brain. The Jetson is the only node in the system with a capable embedded GPU and CUDA support, which makes it the natural home for everything compute-intensive: speech recognition, language model inference, and text-to-speech synthesis. Choosing the Jetson over alternatives was deliberate: TensorRT acceleration on transformer models produces latency profiles that simply aren't achievable on CPU alone, even on fast ARM silicon.

All four nodes connect through a dedicated 8-port Gigabit switch on a local subnet at `192.168.1.0/24`. Wired, not wireless — latency predictability in the AI pipeline matters, and Wi-Fi introduces variance that compounds through the inference chain.

---

## The Network Layer: Zero Trust as a First Principle

<!-- 
📊 DIAGRAM: Insert the homelab network topology diagram here — the one showing the local 192.168.1.0/24 subnet, the Gigabit switch, the router, and the Tailscale Zero Trust overlay with Tailscale IPs (100.1.1.1 through 100.1.1.4). Caption: "The Jarvis network architecture. Local nodes communicate over Gigabit Ethernet; Tailscale provides encrypted, identity-verified remote access without port-forwarding."
-->

Before any AI inference runs, there is a networking problem to solve: how do you connect four nodes in a way that is fast locally, secure remotely, and immune to the common attack surface of homelab setups?

The answer I chose is **Tailscale**, a zero-trust mesh network built on WireGuard. The design philosophy is worth stating explicitly, because it matters architecturally: zero trust means no node is implicitly trusted simply by virtue of being "inside the network." Every connection is authenticated. Every access policy is explicit. The perimeter model — where everything inside the firewall is assumed safe — is abandoned entirely in favor of identity-based access control.

Practically, this means each node gets a stable identity and a Tailscale IP in the `100.x.x.x` CGNAT range:

- `pi-server` → `100.1.1.1`
- `pi-client` → `100.1.1.2`
- `orange-pi` → `100.1.1.3`
- `jetson-nano` → `100.1.1.4`

Access between nodes is governed by **Tailscale ACLs** — declarative, version-controllable policy files that specify exactly which node can reach which service on which port. No port-forwarding on the router. No exposed public-facing services. Remote access from my laptop, anywhere in the world, routes through encrypted point-to-point tunnels established dynamically between endpoints.

The security model is not security-by-obscurity. It is security-by-architecture: the network is designed so that a compromised router cannot cascade into a compromised cluster, and so that remote access never requires weakening the perimeter.

---

## The Voice Pipeline: Six Steps From Microphone to Response

<!-- 
📊 DIAGRAM: Insert the Edge-AI Voice Assistant architecture diagram here — the full pipeline diagram showing the Remote Satellite Node (Orange Pi/ESP32) on the left and the Central AI Hub (NVIDIA Jetson Orin Nano) on the right, with the Docker Container Cluster and numbered steps. This is the centerpiece visual for the post. Give it full width. Caption: "The Jarvis voice pipeline. Six discrete stages transform raw audio into a grounded, actioned response — entirely on local hardware."
-->

The voice pipeline is where the engineering ambition of the project becomes concrete. What follows is a description of how your words become actions, from the moment sound reaches the microphone to the moment a synthesized voice responds.

### Stage 1 — Local Wake Word Detection

An **INMP441 I2S microphone** captures audio continuously at the satellite node (an Orange Pi or ESP32). A lightweight model — **openWakeWord** — runs locally on that node's CPU, listening only for the trigger phrase. This model is deliberately small: it has one job, it does it efficiently, and it runs without GPU acceleration on modest hardware.

The architectural implication is significant: *no audio is ever transmitted until the user explicitly triggers the system.* The microphone is always on, but the privacy boundary is enforced in software at the edge. There is no ambient audio leaving the satellite node. There is no upstream buffer. This is not a policy claim — it is a structural property of the system.

### Stage 2 — Wyoming Satellite Protocol

When the wake word fires, the **Wyoming Satellite Service** takes over. Wyoming is Home Assistant's open protocol for distributed voice satellite nodes. It handles the mechanics of audio capture and stream forwarding, acting as the translation layer between the microphone hardware and the network.

### Stage 3 — Speech-to-Text via Faster-Whisper TRT

The audio stream travels over TCP to the Jetson, where **Faster-Whisper TRT** — a TensorRT-optimized implementation of OpenAI's Whisper architecture — performs speech-to-text transcription using GPU acceleration. The output is clean text, typically available within a fraction of a second of the utterance completing.

TensorRT optimization here is not a performance luxury. It is what makes local transcription viable in a real-time conversational loop. Running the same model on CPU alone would introduce latency that breaks the interaction feel entirely.

### Stage 4 — Language Model Inference via Ollama

The transcribed text passes to **Ollama**, serving **Llama 3.2 (3B parameters, 4-bit quantized)**. The choice of a 3B model at 4-bit precision is a studied trade-off: it fits comfortably within the Jetson's unified memory budget, produces responses with acceptable quality for conversational tasks and home automation commands, and runs at a speed that keeps total pipeline latency under two seconds.

Four-bit quantization — representing model weights in 4 bits rather than the standard 16 or 32 — is one of the more consequential developments in accessible AI over the past two years. The quality degradation relative to full-precision inference is real but often acceptable for task-oriented applications. The memory reduction is dramatic and often the difference between a model that runs on edge hardware and one that doesn't.

The LLM's output is either a natural language response or a **tool call** — a structured JSON object specifying an action to take in the real world. This is what separates a conversational AI from an agentic one.

### Stage 5 — Orchestration via Home Assistant, n8n, and the MCP Bridge

Tool calls from the LLM route to **Home Assistant**, the open-source home automation platform acting as the system's orchestration layer. Home Assistant maintains real-time state for all connected devices — lights, locks, thermostats, sensors — and exposes them through a unified API.

The interface between the LLM and Home Assistant is an **MCP Server** (Model Context Protocol), running on the Jetson. MCP is an emerging standard for exposing structured capabilities to language models as callable tools. The MCP server here wraps Home Assistant's API, presenting home automation actions as discrete, typed tool calls the LLM can invoke with predictable inputs and outputs.

For multi-step automation logic — "lock the doors, lower the thermostat, and set a reminder for 7 AM" — Home Assistant delegates to **n8n**, a self-hosted workflow automation platform. n8n handles the orchestration of composite actions that span multiple devices, services, and timing constraints, giving the system genuine agentic capability rather than single-action command execution.

### Stage 6 — Text-to-Speech via Piper

The LLM's response, once generated, passes to **Piper** — a fast, high-quality offline TTS system. Piper synthesizes natural-sounding speech and streams it back to the satellite node, where it plays through the USB speaker. The acoustic loop closes.

The full round trip — wake word detection to audible response — lands consistently under two seconds under normal load, which is well within the range where a conversation feels natural rather than transactional.

---

## The Monitoring Stack: Observability as a Design Requirement

<!-- 
📸 PHOTO/SCREENSHOT SUGGESTION:
A screenshot of your Grafana (or equivalent) dashboard showing real-time metrics across all four nodes — CPU, memory, GPU utilization on the Jetson, latency panels, container health. If you can include a panel that shows the full pipeline latency end-to-end, that's particularly compelling for a technical audience.
-->

Running a distributed AI system without proper observability is not engineering — it is gambling. The monitoring stack on the Orange Pi 3B exists for a specific reason: when the Jetson is under sustained inference load, the metrics pipeline must remain unaffected. Observability that fails under the conditions when you most need it is worse than useless.

The stack collects telemetry from all four nodes: CPU and memory utilization, GPU utilization and thermal state on the Jetson, disk I/O, inter-node network throughput, Docker container health for every service in the cluster, and end-to-end pipeline latency from audio capture to response delivery.

Alerts fire automatically on anomalous conditions: container restarts, sustained high GPU temperature, inference latency spikes beyond threshold, disk utilization crossing 80%. The goal is that I learn about degraded system state before it produces a noticeable user-facing failure.

This monitoring discipline reflects a broader principle that doesn't get enough emphasis in homelab writing: production-grade systems, even personal ones, deserve production-grade observability. The alternative is debugging emergent problems by SSHing into nodes and running `top` — which is fine once and infuriating the fifth time.

---

## Home Assistant: The Semantic Layer Between AI and the Physical World

It is worth pausing on Home Assistant's role in the architecture, because it is doing more than device control.

Home Assistant is the **semantic layer** that allows the LLM to act on the physical world through structured abstractions. Without it, the language model has no grounded reference to "the bedroom lights" or "the front door lock" — it has only text. Home Assistant provides the real-world state that makes tool calls meaningful: current device states, sensor readings, automation rules, and the action handlers that translate a structured command into a hardware event.

Running Home Assistant locally — rather than relying on its cloud integration — means that device states, presence data, and automation histories never leave the network. Combined with the Tailscale overlay for remote access, the result is a home automation system that is fully accessible from anywhere while being architecturally private.

This is the synthesis the project is trying to demonstrate: that capable AI integration with the physical world does not require surrendering data sovereignty. The capability and the privacy are not in tension. They require different architecture.

---

## On the Broader Significance: Edge AI and the Question of Sovereignty

The Jarvis project is one data point in a broader trend worth tracking carefully: the democratization of capable AI inference at the edge.

Three years ago, running a locally hosted language model that could hold a coherent conversation was a research curiosity. The models required hardware most individuals couldn't afford, and the inference speeds made real-time interaction impractical. That has changed — rapidly and substantially. Quantization techniques, optimized inference runtimes like llama.cpp and TensorRT, and the release of high-quality small models have moved the capability frontier dramatically toward accessible hardware.

The Jetson Orin Nano, at its price point, can run a 3B parameter LLM in real time. That sentence would have been remarkable two years ago. Today it is just a configuration decision.

What this means, I think, is that the question of *where* AI inference happens — and therefore *who* controls it — is becoming a genuine design choice rather than a forgone conclusion. For a long time, the answer was: in the cloud, controlled by a vendor. The answer is increasingly: at the edge, controlled by the person using it.

This has implications that extend well beyond privacy. Edge inference means resilience — the system works without internet connectivity. It means predictability — inference costs are fixed in hardware, not metered by usage. It means auditability — every component of the stack is open-source and inspectable. And it means ownership — when the hardware is yours, the AI is yours.

---

## What's Next: A Full Tutorial Series

<!-- 
📸 PHOTO SUGGESTION:
A close-up of the NVIDIA Jetson Orin Nano's heatsink and GPIO headers, or a shot of the INMP441 microphone mounted in its final position. Something that grounds the project in physical hardware and invites readers to build their own.
-->

This post describes the architecture and the reasoning. The implementation details — the actual configuration, the Docker Compose files, the Tailscale ACL policies, the model selection and quantization parameters — are the subject of a tutorial series I'm writing now.

The series will cover each layer of the stack in depth, designed to be reproducible by anyone with similar hardware:

**Part 1:** Hardware selection, assembly, and initial network configuration
**Part 2:** Zero-trust networking with Tailscale — ACL design and node onboarding
**Part 3:** The Wyoming Satellite — microphone setup and wake word configuration
**Part 4:** Deploying the AI inference stack on the Jetson — Whisper TRT, Ollama, and Piper
**Part 5:** Home Assistant, n8n, and building the MCP bridge
**Part 6:** The monitoring stack — metrics, dashboards, and alerting across all nodes
**Part 7:** Performance tuning — MAXN power mode, NVMe swap, 4-bit quantization, and unified memory management

---

## Closing Thoughts

The commercial AI industry has made a particular set of trade-offs on behalf of its users, and those trade-offs have become so normalized that questioning them can seem naive. The convenience is real. The capabilities are impressive. The access is broad.

But convenience is not the only design value. Privacy, verifiability, resilience, and ownership are also design values — and they are ones that the current commercial model largely forfeits by default.

What I hope Jarvis demonstrates is that these values are not in irreconcilable tension with capability. The models are good enough. The hardware is cheap enough. The software ecosystem — Whisper, Ollama, Home Assistant, Tailscale, Piper, n8n — is mature enough. The engineering is hard, but it is tractable.

We are in an unusual moment in AI development: one where the capability gap between cloud-hosted and locally-hosted inference is closing faster than most people realize, while the infrastructure and tooling for edge deployment are maturing rapidly. That convergence creates an opportunity to ask a question that has not been practically answerable until recently:

What does it look like when the AI is genuinely yours?

Jarvis is one answer. I think there are many others waiting to be built.

---

*Wanghley Soares Martins is a graduate student at Duke University working at the intersection of distributed systems, edge computing, and AI infrastructure. Questions, corrections, and build logs welcome in the comments.*

---

**Related topics:** edge AI · privacy-preserving ML · homelab engineering · distributed systems · home automation · LLM inference · zero-trust networking · TensorRT · open-source AI
