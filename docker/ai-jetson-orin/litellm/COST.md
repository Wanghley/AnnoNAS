# Jetson Nano LLM Cost Estimation Guide

## 1. Baseline Parameters
To calculate cost, we use the following constants based on the Jetson Nano hardware specifications and 2026 energy averages:

* **Power Consumption ($P$):** **10 Watts** (Max-N Performance Mode).
* **Electricity Rate ($R$):** **$0.18 per kWh** (Standard US average).
* **Target Metric:** Cost per **1,000,000 (1M) Tokens**.
* **Quantization:** **Q4_K_M** (Standard 4-bit quantization used by Ollama).

---

## 2. The Core Formula
The cost is derived by determining how many hours it takes to process 1 million tokens and multiplying that by the power cost of the Jetson Nano.

### Output Cost (Generation)
Generation is sequential (one token at a time).

$$Cost_{out} = \left( \frac{P}{1000} \right) \times \left( \frac{1,000,000}{TPS \times 3600} \right) \times R$$

### Input Cost (Prompt/Prefill)
The Jetson's GPU processes input tokens in parallel. On the Nano, the prefill speed is typically **10x faster** than the generation speed.

$$Cost_{in} = \frac{Cost_{out}}{10}$$

---

## 3. How to Add a New Model
If you add a new model to your `config.yaml`, follow these steps to calculate its cost:

### Step 1: Benchmark the Speed
Run the model in Ollama and measure the **Tokens Per Second (TPS)**. You can see this by running:
```bash
ollama run <model_name> --verbose
```
Look for the `eval rate` (this is your Output TPS).

### Step 2: Apply the Power Calculation
Using the 10W baseline at $0.18/kWh, use this simplified "Quick Factor":

* **Output Cost (1M):** $0.05 / TPS$
* **Input Cost (1M):** $Output Cost / 10$

**Example:** If a new 1B model runs at **5 TPS**:
1.  Output: $0.05 / 5 = \$0.01$ per 1M tokens.
2.  Input: $\$0.01 / 10 = \$0.001$ per 1M tokens.

### Step 3: Convert for LiteLLM
LiteLLM requires the cost **per single token**. Divide your 1M token cost by 1,000,000.

* `input_cost_per_token: 0.000000001`
* `output_cost_per_token: 0.00000001`

---

## 4. Operational Considerations
When estimating for the Jetson Nano, keep these "Hidden Factors" in mind:

### RAM and Swapping
The Jetson Nano has **4GB of shared VRAM**. 
* **Models < 3B:** Usually fit entirely in RAM. The formulas above are accurate.
* **Models > 3B:** May trigger **swap** (using the SD card as RAM). 
    * *Effect:* TPS will drop below 0.5. 
    * *Cost:* The hardware stays at full 10W load for 10x longer, increasing the cost per token by **1000%**.

### Thermal Throttling
If the Nano reaches >80°C, it will throttle the clock speed. This reduces TPS and increases the cost per token because the efficiency (Tokens per Watt) drops. Ensure your fan is active if running long inference tasks.

### Idle Draw
The Jetson Nano draws ~5W while idle. If Ollama keeps a model loaded in memory (`keep_alive`), the GPU doesn't fully power down. This adds a "standing cost" of approximately **$0.65 per month** regardless of usage.

---

## 5. Summary Table for Reference
| Parameter | Value |
| :--- | :--- |
| **Power (W)** | 10.0 |
| **Cost (kWh)** | $0.18 |
| **Cost per 1M Tokens (at 1 TPS)** | $0.50 |
| **Cost per 1M Tokens (at 10 TPS)** | $0.05 |

---

*Document Version: 1.0.0 (April 2026)*
*Author: Wanghley Soares Martins*

---
Here’s a clean Python script you can run directly on your Jetson Nano. It calculates the 1M token cost and even generates the exact YAML snippet you need for your LiteLLM `config.yaml`.

### The Script: `calc_llm_cost.py`

```python
import argparse

def calculate_costs(model_name, tps, power_w=10.0, elec_cost_kwh=0.18):
    # Constants
    # Output cost per 1M tokens: (W/1000) * (1,000,000 / (TPS * 3600)) * Cost_per_kWh
    output_1m = (power_w / 1000.0) * (1_000_000 / (tps * 3600)) * elec_cost_kwh
    input_1m = output_1m / 10.0  # Rule of thumb for Jetson prefill
    
    # LiteLLM individual token costs
    output_token = output_1m / 1_000_000
    input_token = input_1m / 1_000_000
    
    print("-" * 40)
    print(f"🚀 COST ESTIMATE FOR: {model_name}")
    print(f"Speed: {tps} tokens/sec | Power: {power_w}W | Rate: ${elec_cost_kwh}/kWh")
    print("-" * 40)
    print(f"Cost per 1M Input Tokens:  ${input_1m:.4f}")
    print(f"Cost per 1M Output Tokens: ${output_1m:.4f}")
    print("-" * 40)
    print("\n📝 LiteLLM config.yaml Snippet:")
    print(f"  - model_name: {model_name}")
    print(f"    litellm_params:")
    print(f"      model: ollama/{model_name}")
    print(f"      api_base: http://host.docker.internal:11434")
    print(f"    model_info:")
    print(f"      input_cost_per_token: {input_token:.12f}")
    print(f"      output_cost_per_token: {output_token:.12f}")
    print("-" * 40)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Calculate Jetson Nano LLM Costs")
    parser.add_argument("name", help="Model name (e.g., llama3.2)")
    parser.add_argument("tps", type=float, help="Measured tokens per second (eval rate)")
    parser.add_argument("--power", type=float, default=10.0, help="Power in Watts (default: 10)")
    parser.add_argument("--rate", type=float, default=0.18, help="Electricity rate per kWh (default: 0.18)")
    
    args = parser.parse_args()
    calculate_costs(args.name, args.tps, args.power, args.rate)
```

---

### How to use it:

1.  **Get your TPS:**
    Run your model once with the verbose flag to see how fast it actually runs on your hardware:
    ```bash
    ollama run granite4:3b --verbose
    ```
    *Look for the `eval rate` (e.g., 1.4 tokens/s).*

2.  **Run the script:**
    Save the code above as `calc_llm_cost.py` and run:
    ```bash
    # Usage: python3 calc_llm_cost.py <model_name> <tps>
    python3 calc_llm_cost.py granite4:3b 1.4
    ```

3.  **Adjusting for Price:**
    If your electricity price changes or you're running in 5W mode, you can pass those as flags:
    ```bash
    python3 calc_llm_cost.py smollm2 5.0 --power 5 --rate 0.12
    ```
