# Qwen3.6 35B-A3B MTP MXFP4_MOE

This file is the source-of-truth tuning summary for `Qwen3.6-35B-A3B-MXFP4_MOE.gguf` on Ryzen AI Max+ 395 / Radeon 8060S.

## Model

- GGUF: `Qwen3.6-35B-A3B-MXFP4_MOE.gguf`
- Family: `unsloth/Qwen3.6-35B-A3B-MTP-GGUF`
- Local file tested: `Qwen3.6-35B-A3B-MXFP4_MOE.gguf`
- Active params: about 3B active MoE
- Feature used: embedded MTP head through llama.cpp `--spec-type draft-mtp`
- Best target context tested here: `262144`

The `MXFP4_MOE` filename describes the MoE weight quantization. MTP is still part of this GGUF family, but it only activates when llama.cpp is launched with `--spec-type draft-mtp`.

The launcher and benchmark examples search `%USERPROFILE%\Downloads` and the default Hugging Face cache under `%USERPROFILE%\.cache\huggingface\...`. Pass `-ModelPath C:\path\to\Qwen3.6-35B-A3B-MXFP4_MOE.gguf` if your GGUF lives somewhere else.

## Hardware And Runtime

- CPU/APU: AMD Ryzen AI Max+ 395
- GPU: AMD Radeon 8060S integrated GPU
- Memory model: unified memory
- OS/backend tested: Windows HIP/ROCm
- llama.cpp: Unsloth b9704-era `llama-server.exe`
- Serving mode: single slot, `--parallel 1`

## Best 262K Settings

Use this profile for the standalone Hermes/local endpoint launcher:

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
--spec-draft-n-max 3 `
--spec-draft-ngl 999 `
--batch-size 2048 `
--ubatch-size 1024 `
--threads 28 `
--threads-batch 28 `
--poll 100 `
--poll-batch 1 `
--no-mmap
```

`threads=24` is nearly tied with `threads=28` and is a reasonable lower-CPU fallback:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-qwen36-35b-a3b-mxfp4-mtp-262k.ps1 -Threads 24 -ThreadsBatch 24
```

## Best Results

All rows below are 262K context on the local machine.

| Case | Max tokens | Completion tokens | Eval tok/s | Wall tok/s | Draft acceptance |
| --- | ---: | ---: | ---: | ---: | ---: |
| `draft-mtp n=3, t28, ub1024` | 1024 | 685 | 51.26 | 49.88 | 0.7576 |
| `draft-mtp n=3, t24, ub1024` | 1024 | 685 | 51.10 | 49.65 | 0.7576 |
| `draft-mtp n=4, t24, ub1536` | 1024 | 702 | 49.32 | 48.10 | 0.6835 |
| `no MTP, t28, ub1024` | 512 | 512 | 37.97 | 37.07 | 0.0000 |

Shorter 256-token sweeps peaked higher:

| Case | Eval tok/s | Wall tok/s | Draft acceptance |
| --- | ---: | ---: | ---: |
| `draft-mtp n=3, t24, ub1024` | 55.29 | 51.37 | 0.7061 |
| `draft-mtp n=3, t28, ub1024` | 54.69 | 50.64 | 0.7061 |
| `draft-mtp n=4, t24, ub1536` | 53.35 | 49.60 | 0.6399 |

Practical conclusion: use `n=3`, `ub1024`, and either `t28` for absolute speed or `t24` for a slightly quieter system. This quant did not reach the 150 tok/s numbers reported for separate vLLM/RDNA4 multi-GPU MXFP4 setups, but it is the fastest GGUF path measured here at 262K.

## Draft Sweep

At `threads=24`, `ubatch=1536`, and 512 requested tokens:

| Draft n | Eval tok/s | Wall tok/s | Draft acceptance |
| ---: | ---: | ---: | ---: |
| 1 | 44.09 | 42.68 | 0.9139 |
| 2 | 50.70 | 48.87 | 0.7970 |
| 3 | 52.77 | 50.83 | 0.7395 |
| 4 | 52.76 | 50.76 | 0.6739 |
| 5 | 47.13 | 45.58 | 0.5564 |
| 6 | 47.09 | 45.57 | 0.5209 |

`n=3` and `n=4` were essentially tied in that sweep, but `n=3` stayed better in follow-up tests.

## Reproduce

Run the MXFP4 server:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-qwen36-35b-a3b-mxfp4-mtp-262k.ps1
```

Benchmark the confirmed winners:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bench-qwen36-mtp.ps1 `
  -ModelPattern Qwen3.6-35B-A3B-MXFP4_MOE.gguf `
  -Case "hip-mtp-n3-t24-ub1024,hip-mtp-n3-t28-ub1024,hip-mtp-n4-t24-ub1536" `
  -Context 262144 `
  -MaxTokens 1024 `
  -OutCsv .\results\qwen36-35b-a3b-mtp-262k\mxfp4-moe-best-confirm-1024tok.csv
```

Run the no-MTP baseline:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bench-qwen36-mtp.ps1 `
  -ModelPattern Qwen3.6-35B-A3B-MXFP4_MOE.gguf `
  -Case hip-no-mtp-t28-ub1024 `
  -Context 262144 `
  -MaxTokens 512
```

## Agent Notes

1. This is still a GGUF/llama.cpp path, unlike safetensors MXFP4 releases for vLLM or MLX releases for Apple Silicon.
2. Do not assume `MXFP4_MOE` implies MTP is enabled. The launch flags must include `--spec-type draft-mtp`.
3. Changing quant changed the best draft depth from `n=2` on `UD-Q4_K_XL` to `n=3` here.
4. Keep f16 KV at 262K unless a fresh benchmark proves another KV type is faster.
5. The BAT launcher auto-searches `Downloads` and the Unsloth HF cache for this exact GGUF name.
6. Prefer keeping one copy in the Unsloth HF cache snapshot; avoid duplicating the 22 GB file unless a separate tool truly needs it.
