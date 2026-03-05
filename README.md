# ece751
RTL development for parameterized KV cache

# KV Cache RTL Prototype

                ┌───────────────┐
                │ KV Controller │
                └──────┬────────┘
                       │
       ┌───────────────┼───────────────┐
       │               │               │
   ┌───────┐       ┌───────┐       ┌───────┐
   │Bank 0 │       │Bank 1 │  ...  │Bank 7 │
   │Head 0 │       │Head 1 │       │Head 7 │
   └───────┘       └───────┘       └───────┘