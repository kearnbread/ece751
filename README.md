# KV Cache Accelerator RTL (Prototype)

## Overview

This repository contains an **RTL prototype of a multi-head KV cache subsystem** intended for transformer inference accelerators. The design supports **mixed-precision KV storage** (FP16 / INT8 / INT4) with **per-token per-head scaling** and a **streaming read interface** suitable for attention decode.

The goal is to model the behavior of a **hardware KV cache used in LLM accelerators**, where keys and values are stored in SRAM and streamed into the attention pipeline.

The current implementation focuses on:

* Efficient **KV cache storage**
* **Per-head precision support**
* **Streaming decode reads**
* **Dequantization preparation**

Future work will integrate the cache with a **GEMM / attention pipeline model**.

---

# Implemented Modules

## `kv_bank.sv`

### Purpose

Implements the **storage for a single attention head**.

Each bank stores tokens for one head and supports **packing multiple tokens per SRAM line** depending on precision.

### Features

* Parameterized `HEAD_DIM`
* Parameterized `MAX_TOKENS`
* Precision modes:

  * FP16
  * INT8
  * INT4
* Token packing per line:

| Precision | Tokens per Line |
| --------- | --------------- |
| FP16      | 1               |
| INT8      | 2               |
| INT4      | 4               |

### Responsibilities

Write:

* Accept token vectors
* Pack tokens into SRAM lines

Read:

* Extract token slot from packed line
* Output quantized vector + scale

### Outputs

```
rd_vector
rd_scale
```

---

# `kv_cache.sv`

### Purpose

Instantiates **one `kv_bank` per head**.

This module manages:

* Parallel writes across heads
* Streaming reads across tokens
* Head-level parallelism

### Architecture

```
HEAD 0 -> kv_bank
HEAD 1 -> kv_bank
HEAD 2 -> kv_bank
...
HEAD N -> kv_bank
```

### Key Design Choices

1. **All heads can be written simultaneously**

```
wr_vector [0:NUM_HEADS-1]
```

Each head receives its own vector input.

2. **Per-head precision**

```
parameter PRECISION [0:NUM_HEADS-1]
```

Allows heterogeneous precision across heads.

3. **Streaming decode reads**

The module contains a small FSM that produces:

```
token t
token t+1
token t+2
...
```

for the requested sequence length.

---

# `kv_cache_top.sv`

### Purpose

Top-level wrapper that instantiates:

```
Key cache
Value cache
```

### Structure

```
kv_cache_top
 ├── kv_cache (KEYS)
 └── kv_cache (VALUES)
```

The module routes writes to the appropriate cache and provides synchronized read outputs.

### Responsibilities

* Select K or V cache during write
* Broadcast read control to both caches
* Output K/V streams to downstream compute

---

# `kv_dequant.sv`

### Purpose

Converts quantized KV cache values back to **16-bit lanes** for compute units.

### Behavior

| Input Precision | Operation    |
| --------------- | ------------ |
| FP16            | pass-through |
| INT8            | sign extend  |
| INT4            | sign extend  |

The module **does not apply scale multiplication**.

Scaling is expected to occur inside the **attention compute pipeline**.

### Why

Avoids inserting many multipliers in the memory read path.

---

# Current Dataflow

## Write Path

```
Transformer block
      │
      ▼
kv_cache_top
      │
      ▼
kv_cache (per-head banks)
      │
      ▼
kv_bank SRAM storage
```

---

## Read Path (Decode)

```
kv_bank
   │
   ▼
kv_cache
   │
   ▼
kv_cache_top
   │
   ▼
kv_dequant
   │
   ▼
Attention compute pipeline (future)
```

---

# What Still Needs to Be Built

## 1. Cache Wrapper Interface

A wrapper module should connect the KV cache to the **accelerator top-level**.

Suggested module:

```
kv_cache_wrapper.sv
```

Responsibilities:

* Interface with transformer pipeline
* Accept new K/V tokens
* Trigger decode reads
* Deliver vectors to compute

Example interface:

```
write_k_valid
write_v_valid
write_token
write_head_vectors

read_request
read_start_token
read_length
```

---

## 2. Attention Compute / GEMM Pipeline

A simplified compute model should be added to simulate attention behavior.

Possible implementations:

### Option A (Recommended)

Behavioral GEMM pipeline

```
Q × K^T
softmax
attention × V
```

This can be implemented with:

* simple matrix multipliers
* pipeline registers

Goal is **functional simulation**, not final hardware.

---

### Option B

Stub module

```
attention_pipeline_stub.sv
```

Outputs random or deterministic values while verifying:

* bandwidth
* read ordering
* timing

---

## 3. Scale Application

A future stage should apply the quantization scale.

Suggested module:

```
kv_scale_apply.sv
```

```
extended_vector × scale
```

This stage should sit **inside the compute pipeline**, not inside the cache.

---

## 4. Prefill Mode

Current implementation primarily targets **decode streaming**.

Prefill support could include:

* burst writes
* larger read bursts
* higher bandwidth modes

---

## 5. Testbench

Recommended testbench hierarchy:

```
tb/
 ├── tb_kv_bank.sv
 ├── tb_kv_cache.sv
 ├── tb_kv_cache_top.sv
```

Tests should verify:

* FP16 writes/reads
* INT8 packing
* INT4 packing
* token extraction
* multi-head parallel writes
* streaming decode

---

# Possible Future Optimizations

### XOR-based KV compression

### SRAM banking for higher throughput

### Burst decode reads

### Double-buffered KV banks

### Prefetch logic

---

# Example System Diagram

```
               +----------------------+
               |  Transformer Block   |
               +----------+-----------+
                          |
                          v
                +-------------------+
                |   kv_cache_top    |
                +---------+---------+
                          |
        +-----------------+-----------------+
        |                                   |
        v                                   v
  +------------+                     +------------+
  | kv_cache K |                     | kv_cache V |
  +------------+                     +------------+
        |                                   |
        v                                   v
     kv_bank                             kv_bank
   (per head)                         (per head)
        |                                   |
        +-----------+-------------+---------+
                    |
                    v
                kv_dequant
                    |
                    v
           Attention Compute
               (future)
```

---

# Project Status

| Component         | Status      |
| ----------------- | ----------- |
| kv_bank           | Implemented |
| kv_cache          | Implemented |
| kv_cache_top      | Implemented |
| kv_dequant        | Implemented |
| compute pipeline  | TODO        |
| wrapper interface | TODO        |
| testbench         | TODO        |

---

# Goal

Provide a **clean RTL model of a mixed-precision KV cache subsystem** that could be used inside an **LLM inference accelerator**.

The design emphasizes:

* modularity
* parameterization
* hardware realism
* scalability across heads and tokens

---
