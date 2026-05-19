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
