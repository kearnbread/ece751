# ece751
RTL development for parameterized KV cache

# KV Cache RTL Prototype

                ┌──────────────────────┐
                │   KV CACHE CTRL      │
                │                      │
Write vectors → │ packing + addressing │
                │                      │
Read bursts  ←  │ stream scheduler     │
                └──────────┬───────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
     ┌───────┐         ┌───────┐         ┌───────┐
     │Bank 0 │         │Bank 1 │         │Bank 7 │
     │Head 0 │         │Head 1 │         │Head 7 │
     └───────┘         └───────┘         └───────┘
         │                 │                 │
         └────────── parallel vectors ───────┘
                          │
                     Attention MAC