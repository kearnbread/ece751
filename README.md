# ece751
RTL development for parameterized KV cache

# KV Cache RTL Prototype

This repository contains the initial RTL framework for our mixed-precision KV cache project.

To get us moving quickly, I set up the repo and generated a starter skeleton using an LLM to help scaffold the basic module structure (top-level wiring, parameterization, memory model, etc.). The goal was simply to avoid starting from a blank slate and to give us something concrete to iterate on.

This is just a starting point — we’ll review, modify, and refine everything together as we define:

- Interface structure  
- Address generation strategy  
- Metadata handling  
- Format abstraction (FP16 / INT8 / INT4)  
- Performance counters and measurement hooks  

The focus right now is building a clean, parameterized KV cache model that lets us evaluate:

- Memory footprint tradeoffs  
- Bandwidth requirements  
- Latency and cycle cost  
- Metadata overhead  

From here, we can shape the architecture to match our final design decisions and integrate whatever quantization strategy the Python model team settles on.

Let’s use this as a foundation and build it into our own implementation.