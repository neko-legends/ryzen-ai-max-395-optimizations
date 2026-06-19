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

Best stable result:

- Case: `hip-mtp-n2-t24-ub1536`
- Context: `262144`
- Eval throughput: `51.75-52.95 tok/s`
- Wall throughput: `48.16-49.20 tok/s`
- Draft acceptance: `0.7789`
