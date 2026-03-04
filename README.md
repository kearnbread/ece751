# ece751
RTL development for parameterized KV cache

# KV Cache RTL Prototype

This repository contains the initial RTL framework for our mixed-precision KV cache project.

To get things moving quickly, I set up this repo and added some starter skeleton modules to give us structure and direction. The initial code was generated with assistance from ChatGPT to help bootstrap the architecture (top-level wiring, parameterization, memory model, etc.), since I didn’t have time to design everything from scratch.

This is **not final design code** — it’s a starting point. We should review everything together and refine:

- Interface definitions  
- Address generation strategy  
- Metadata handling  
- Format abstraction (FP16 / INT8 / INT4)  
- Performance counters and measurement hooks  

The goal right now is to establish a clean, parameterized hardware framework so we can evaluate:

- Memory footprint tradeoffs  
- Bandwidth requirements  
- Latency and cycle cost  
- Metadata overhead  

Quantization arithmetic is intentionally abstracted for now and can be added later once the Python model is finalized.

Let’s treat this as a foundation we’ll iterate on and make fully our own.