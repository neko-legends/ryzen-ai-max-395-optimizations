# Qwen3.6 35B-A3B MTP UD-Q4_K_XL

This file is the source-of-truth tuning summary for the locally installed Qwen3.6 35B-A3B MTP GGUF on Ryzen AI Max+ 395 / Radeon 8060S.

## Model

- GGUF: `Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf`
- Family: `unsloth/Qwen3.6-35B-A3B-MTP-GGUF`
- Active params: about 3B active MoE
- Feature used: embedded MTP head through llama.cpp `--spec-type draft-mtp`
- Best target context tested here: `262144`

## Hardware And Runtime

- CPU/APU: AMD Ryzen AI Max+ 395
- GPU: AMD Radeon 8060S integrated GPU
- Memory model: unified memory
- OS/backend tested: Windows HIP/ROCm
- llama.cpp: Unsloth b9704-era `llama-server.exe`
- Serving mode: single slot, `--parallel 1`

## Best 262K Settings

```powershell
--ctx-size 262144 `
--parallel 1 `
--flash-attn on `
--no-context-shift `
-ngl 999 `
--cache-type-k f16 `
--cache-type-v f16 `
--spec-draft-type-k f16 `
--spec-draft-type-v f16 `
--spec-type draft-mtp `
--spec-draft-n-max 2 `
--spec-draft-ngl 999 `
--batch-size 2048 `
--ubatch-size 1536 `
--threads 24 `
--threads-batch 24 `
--poll 100 `
--poll-batch 1 `
--no-mmap
```

The standalone launcher uses these by default:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\localai\qwen36-35b-a3b-mtp-gguf\start-qwen36-35b-a3b-mtp-262k.ps1
```

## Best Results

All rows below are 262K context, 256 generated tokens, deterministic request, and measured from llama.cpp `eval time`.

| Case | Eval tok/s | Wall tok/s | Draft acceptance |
| --- | ---: | ---: | ---: |
| `draft-mtp n=2, t24, ub1536` | 52.95 | 49.20 | 0.7789 |
| `draft-mtp n=2, t24, ub1536` rerun | 51.75 | 48.16 | 0.7789 |
| `draft-mtp n=2, t28, ub1536` | 51.87 | 48.32 | 0.7789 |
| `draft-mtp n=3, t24, ub1024` | 51.95 | 48.33 | 0.6786 |
| Studio-like baseline | 22.88 | 20.82 | 0.8421 |

Practical conclusion: use `n=2`, `t24`, `ub1536`. `t28` is close, but `t24` is the safer default.

## What Failed Or Regressed

These settings looked plausible but were bad on this model/hardware at 262K:

| Setting | Result |
| --- | --- |
| `q8_0` KV | about 23 eval tok/s |
| `q4_0` KV | about 22 eval tok/s |
| mmap enabled | about 22 eval tok/s |
| `ngram-mod,draft-mtp` | about 22 eval tok/s |
| `--spec-draft-p-min 0.75` | about 21 eval tok/s despite high acceptance |
| Windows Vulkan backend | about 22 eval tok/s |
| Studio-like `threads=2` | about 23 eval tok/s |

## Agent Notes

If you are an AI agent adapting this to another local GGUF:

1. Do not use `draft-mtp` unless the model has an embedded MTP head or a configured draft model.
2. Keep f16 KV for this Qwen model on this APU unless memory pressure forces a smaller KV type.
3. Benchmark throughput, not only acceptance. High acceptance with `p-min` was slower.
4. Treat `-b 2048` as sticky for this profile. Both `-b 1024` and `-b 4096` regressed badly in local tests.
5. Retune `--spec-draft-n-max`, `--threads`, and `--ubatch-size` after changing quant, backend, context, or model.
6. Keep `--parallel 1`; multi-slot serving changes the memory and scheduling profile.
7. If a run suddenly falls from about 50 tok/s to about 20 tok/s with identical flags, check system memory pressure, background GPU work, and thermal/power state, then rerun before concluding the flags are bad.

## Reproduce The Main Sweep

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\localai\qwen36-35b-a3b-mtp-gguf\bench-qwen36-mtp.ps1 `
  -Case "hip-mtp-n1,hip-mtp-n2,hip-mtp-n3,hip-mtp-n4,hip-mtp-n5,hip-mtp-n6" `
  -Context 262144 `
  -OutCsv .\results\qwen36-35b-a3b-mtp-262k\my-sweep.csv
```

Fine-tune the current winner:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\localai\qwen36-35b-a3b-mtp-gguf\bench-qwen36-mtp.ps1 `
  -Case "hip-mtp-n2-t24-ub512,hip-mtp-n2-t24-ub1536,hip-mtp-n2-t24-ub2048,hip-mtp-n2-t28-ub1536" `
  -Context 262144 `
  -OutCsv .\results\qwen36-35b-a3b-mtp-262k\my-final.csv
```

Use another local model path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\localai\qwen36-35b-a3b-mtp-gguf\bench-qwen36-mtp.ps1 `
  -ModelPath C:\path\to\model.gguf `
  -Case hip-mtp-n2-t24-ub1536 `
  -Context 262144
```
