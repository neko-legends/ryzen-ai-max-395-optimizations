# Qwen3.6 35B-A3B MTP 262K Results

Raw CSV outputs from the 262K context tuning sweep.

Important files:

- `qwen36-mtp-262k-sweep-a.csv`: `draft-mtp` n=1,2,3.
- `qwen36-mtp-262k-sweep-b.csv`: `draft-mtp` n=4,5,6.
- `qwen36-mtp-262k-threads.csv`: thread count sweep.
- `qwen36-mtp-262k-batch.csv`: batch and ubatch sweep.
- `qwen36-mtp-262k-misc.csv`: q8/q4 KV, mmap, p-min, ngram, Vulkan, Studio-like baseline.
- `qwen36-mtp-262k-deterministic.csv`: deterministic shortlist.
- `qwen36-mtp-262k-final-narrow.csv`: final narrow sweep around `t24/t28` and `ub1536`.
- `mxfp4-moe-kv-unified-confirm.csv`: 2026-06-20 explicit `--kv-unified` retest.
- `mxfp4-moe-no-kv-unified-confirm.csv`: 2026-06-20 no-explicit-unified-KV control.
- `mxfp4-moe-no-metrics-rerun.csv`: 2026-06-20 no-`--metrics` isolation check.
- `mxfp4-moe-f16-launcher-equivalent-rerun.csv`: 2026-06-20 launcher-equivalent explicit f16 KV check.
- `mxfp4-moe-fit-off-rerun.csv`: 2026-06-20 `--fit off` check.
- `mxfp4-moe-mlock-rerun.csv`: 2026-06-20 `--mlock` check.
- `mxfp4-moe-downloads-hardlink-rerun.csv`: 2026-06-20 old Downloads-path hardlink check.
- `ud-q4-control-rerun.csv`: 2026-06-20 older `UD-Q4_K_XL` control.

Best stable result:

- Case: `hip-mtp-n2-t24-ub1536`
- Context: `262144`
- Eval throughput: `51.75-52.95 tok/s`
- Wall throughput: `48.16-49.20 tok/s`
- Draft acceptance: `0.7789`

2026-06-20 retest note:

- The current runtime state retested around `21-22 eval tok/s` for both `MXFP4_MOE` and `UD-Q4_K_XL`.
- Explicit `--kv-unified`, `--mlock`, and `--fit off` did not recover the earlier `50+ tok/s` cluster.
- Keep `--kv-unified` opt-in until a future 262K benchmark proves it helps this profile.
