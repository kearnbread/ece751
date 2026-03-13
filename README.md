# KV Cache with Mixed-Precision Quantization (SystemVerilog)

## Overview

This project implements a **parameterizable KV cache architecture for transformer inference accelerators**. The design supports **mixed precision per attention head** and includes infrastructure for **quantized storage of Key/Value vectors**.

The goal of the architecture is to reduce **memory footprint and bandwidth** during autoregressive inference by storing KV vectors in **INT8 or INT4** instead of full **FP16**, while preserving compatibility with FP16 compute units.

The system currently includes:

* `kv_cache` — main storage module
* `kv_bank` — per-head memory bank
* `kv_quant` — quantization module (simplified implementation)
* `kv_cache_tb` — verification testbench with deterministic stimulus

The design supports **per-head precision configuration** and **per-token scaling factors**, matching the structure used in many modern LLM inference systems.

---

# Architecture

## KV Cache in Transformer Inference

In autoregressive transformers, the **Key and Value vectors from previous tokens must be stored** so they can be reused when computing attention for new tokens.

For a sequence of tokens:

```
Token0 → K0,V0 stored
Token1 → K1,V1 stored
Token2 → K2,V2 stored
...
```

When computing attention for token *t*, the model must read:

```
K0...Kt
V0...Vt
```

This means memory grows linearly with sequence length.

Because these vectors are large, **KV cache storage dominates memory usage during inference**.

Typical dimensions:

```
num_heads = 32
head_dim  = 128
sequence  = 4096 tokens
precision = FP16 (2 bytes)
```

Memory required:

```
32 * 128 * 4096 * 2 ≈ 32 MB per layer
```

Quantization reduces this dramatically.

---

# Quantized KV Cache

Instead of storing FP16 values, vectors are stored as:

```
quantized_vector
scale
```

Later reconstruction approximates the original value:

```
x ≈ q * scale
```

Where:

```
x = original FP16 value
q = quantized INT8 / INT4 value
scale = FP16 scaling factor
```

Quantization reduces memory usage:

| Precision | Bits | Memory Reduction |
| --------- | ---- | ---------------- |
| FP16      | 16   | baseline         |
| INT8      | 8    | 2× smaller       |
| INT4      | 4    | 4× smaller       |

---

# Per-Head Mixed Precision

Different heads may use different precision levels.

Example configuration:

```
HEAD 0 → FP16
HEAD 1 → INT8
HEAD 2 → INT8
HEAD 3 → INT4
```

This is controlled by the parameter:

```
PRECISION[NUM_HEADS]
```

Encoding:

```
0 → FP16
1 → INT8
2 → INT4
```

Mixed precision allows trading accuracy for memory savings.

---

# Per-Token Scaling

Quantization scale is computed **per head per token**.

Why per-token?

Vector magnitude can vary significantly between tokens.

Example:

```
Token0: values ≈ 0.01
Token1: values ≈ 2.5
Token2: values ≈ 0.3
```

Using a single scale across all tokens would introduce large error.

Instead we compute:

```
scale = max(|x_i|) / QMAX
```

Where:

```
QMAX = 127 for INT8
QMAX = 7 for INT4
```

This scale is stored in the cache alongside the quantized vector.

---

# System Dataflow

The overall pipeline:

```
Attention Output (FP16)
        │
        ▼
      kv_quant
        │
        ├── quantized vector
        └── scale
        │
        ▼
      kv_cache
        │
        ├── vector_mem[head][token]
        └── scale_mem[head][token]
```

During attention computation:

```
kv_cache read
      │
      ▼
dequantization
      │
      ▼
FP16 attention math
```

---

# kv_cache Module

## Purpose

Stores quantized KV vectors and their associated scale values.

Each attention head is implemented as an independent **bank**.

## Parameters

```
NUM_HEADS
HEAD_DIM
MAX_TOKENS
PRECISION[NUM_HEADS]
```

## Write Interface

```
wr_valid
wr_token
wr_vector[NUM_HEADS]
wr_scale[NUM_HEADS]
```

A write stores the vector and scale for the specified token.

## Read Interface

```
rd_req
rd_start_token
rd_len
```

Outputs vectors sequentially for attention computation.

---

# kv_bank Module

Each head has its own memory bank.

Responsibilities:

* store vectors
* store scale values
* implement token indexing
* pack vectors based on precision

### Line Width

Internal line width is:

```
LINE_WIDTH = HEAD_DIM * 16
```

This represents the **maximum width if stored in FP16**.

### Tokens per Line

```
PRECISION = FP16 → 1 token per line
PRECISION = INT8 → 2 tokens per line
PRECISION = INT4 → 4 tokens per line
```

Computed as:

```
TOKENS_PER_LINE =
    FP16 → 1
    INT8 → 2
    INT4 → 4
```

Slot width:

```
SLOT_WIDTH = LINE_WIDTH / TOKENS_PER_LINE
```

---

# kv_quant Module

`kv_quant` converts FP16 vectors into quantized representations.

Current implementation is intentionally simple:

```
FP16 → passthrough
INT8 → upper 8 bits of FP16
INT4 → upper 4 bits of FP16
scale = 1
```

This allows verifying the architecture without implementing full quantization logic.

Future versions may include:

```
max abs reduction
scale computation
quantization multiply
clamping
```

---

# Quantization Math (Future Implementation)

Typical quantization process:

1. Compute max absolute value

```
max_val = max(|x_i|)
```

2. Compute scale

```
scale = max_val / QMAX
```

3. Quantize

```
q_i = round(x_i / scale)
```

4. Store

```
vector = q
scale  = scale
```

During read:

```
x ≈ q * scale
```

---

# Testbench Design

The testbench:

```
kv_cache_tb
```

performs deterministic testing.

Steps:

1. Reset system
2. Write tokens sequentially
3. Store reference vectors
4. Issue read request
5. Compare DUT output with reference

The reference model **sign-extends quantized values** back to FP16 to verify correctness.

Example for INT8:

```
q = 8-bit value

ref = {{8{q[7]}}, q}
```

For INT4:

```
ref = {{12{q[3]}}, q}
```

---

# Example Vector Packing

HEAD_DIM = 2

INT8 case:

Input FP16:

```
0002 0001
```

Quantized vector:

```
00000201
```

Memory stores:

```
02 01
```

Read path reconstructs:

```
0002 0001
```

---

# Design Properties

The architecture provides:

* mixed precision per head
* per-token scaling
* parameterizable head dimension
* configurable token capacity
* deterministic verification

---

# Possible Future Improvements

## Real Quantization Logic

Add:

```
max abs reduction
scale calculation
reciprocal multiplication
clamping
```

## SRAM Optimization

Store vectors in compressed form:

```
INT8 → 8 bits per element
INT4 → 4 bits per element
```

instead of fixed FP16 layout.

## Dequantization Hardware

Add module:

```
kv_dequant
```

which reconstructs FP16 vectors during read.

## Attention Engine Integration

Full inference datapath:

```
token embedding
      │
attention compute
      │
kv_quant
      │
kv_cache
      │
attention read
```

---

# Summary

This project implements a **parameterizable mixed-precision KV cache architecture** suitable for transformer inference accelerators.

Key features:

* mixed precision per attention head
* quantized KV storage
* per-token scaling
* modular architecture
* synthesizable SystemVerilog

The current implementation focuses on **architecture validation**, while future work can extend the quantization logic and integrate it into a full transformer inference pipeline.
