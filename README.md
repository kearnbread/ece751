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

---

## Module Overview

Below is a brief description of each RTL module and its intended purpose in the current prototype.

### `kv_cache_top.sv`
Top-level wrapper that connects all submodules.  
Handles external interface signals (read/write, format mode, metadata) and wires together address generation, storage, and performance tracking.

---

### `kv_addr_gen.sv`
Generates linear memory addresses from logical KV indices (token, head, and eventually head dimension).  
Defines the memory layout of the KV cache and is critical for ensuring consistent storage organization.

---

### `kv_format_adapter.sv`
Format abstraction layer.  
Accepts pre-quantized input streams (FP16, INT8, INT4) and standardizes them for storage.  
Currently acts as a passthrough, but structured to support packing/unpacking logic later if needed.

---

### `kv_sram_model.sv`
Synthesizable SRAM/BRAM-style memory model.  
Responsible for storing KV data and servicing read/write requests.  
Used to evaluate storage footprint, bandwidth usage, and access latency.

---

### `kv_metadata_store.sv`
Separate storage block for metadata (e.g., scale factors).  
Allows measurement of metadata overhead and supports future extensions like per-head or per-channel scaling.

---

### `kv_perf_counters.sv`
Tracks performance metrics such as:
- Total cycles
- Bits written
- Bits read

Used to estimate effective bandwidth and evaluate format tradeoffs (FP16 vs INT8 vs INT4).

---

## Design Philosophy (Current Phase)

- Quantization arithmetic is intentionally abstracted.
- The RTL focuses on format-agnostic storage, bandwidth, and latency modeling.
- The architecture is parameterized to allow future integration of quantize/dequant logic once the Python model is finalized.