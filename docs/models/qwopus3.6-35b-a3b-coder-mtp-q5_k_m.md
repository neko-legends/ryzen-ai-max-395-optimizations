# Qwopus3.6 35B-A3B Coder MTP Q5_K_M

This file is the setup note for `Qwopus3.6-35B-A3B-Coder-MTP-Q5_K_M.gguf` on Ryzen AI Max+ 395 / Radeon 8060S.

## Model

- GGUF: `Qwopus3.6-35B-A3B-Coder-MTP-Q5_K_M.gguf`
- Hugging Face repo: `Jackrong/Qwopus3.6-35B-A3B-Coder-MTP-GGUF`
- Local target: `%USERPROFILE%\.cache\huggingface\hub\models--Jackrong--Qwopus3.6-35B-A3B-Coder-MTP-GGUF\snapshots\manual`
- File size: about `23.60 GiB`
- Base family: Qwopus3.6 / Qwen3.6 35B-A3B sparse MoE
- Focus: thinking-off coding-agent workflows
- Feature used locally: embedded MTP head through llama.cpp `--spec-type draft-mtp`

The model card says the central target is thinking-off execution for coding agents, and the highlighted evaluation quant is Q5_K_M. That is why the local launcher defaults `--reasoning off`.

## Endpoint

Qwopus uses a separate local port from the Qwen profiles:

```text
http://127.0.0.1:8004/v1
```

This lets Hermes keep Qwen and Qwopus as separate saved custom providers:

- Qwen MXFP4 MTP: `http://127.0.0.1:8001/v1`
- Qwopus Coder Q5_K_M MTP: `http://127.0.0.1:8004/v1`

## Install

Double-click:

```text
scripts\localai\qwopus36-35b-a3b-coder-mtp-gguf\install-qwopus36-35b-a3b-coder-mtp-q5-k-m.bat
```

The install script:

1. Downloads the GGUF into the Hugging Face cache.
2. Adds a Hermes saved custom provider named `Qwopus3.6 35B-A3B Coder MTP Q5_K_M 262K`.
3. Leaves the active Hermes default unchanged unless `-ConfigureHermesDefault` is passed to the PowerShell installer.

To make Qwopus the active Hermes default:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\localai\qwopus36-35b-a3b-coder-mtp-gguf\install-qwopus36-35b-a3b-coder-mtp-q5-k-m.ps1 -ConfigureHermesDefault
```

## Start Server

Double-click:

```text
scripts\localai\qwopus36-35b-a3b-coder-mtp-gguf\start-qwopus36-35b-a3b-coder-mtp-q5-k-m-262k.bat
```

PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\localai\qwopus36-35b-a3b-coder-mtp-gguf\start-qwopus36-35b-a3b-coder-mtp-q5-k-m-262k.ps1
```

## Launch Profile

The launcher intentionally reuses the current best Qwen MXFP4 MTP profile:

```powershell
-c 262144 `
--spec-type draft-mtp `
--spec-draft-n-max 3 `
--cache-type-k f16 --cache-type-v f16 `
--spec-draft-type-k f16 --spec-draft-type-v f16 `
-b 2048 -ub 1024 `
-t 28 -tb 28 `
--poll 100 --poll-batch 1 `
--no-mmap `
-ngl 999 `
--flash-attn on `
--no-context-shift `
--parallel 1 `
--reasoning off
```

## Quick Benchmark

One quick 262K check was run after install, using the same short benchmark prompt as the Qwen harness and 512 generated tokens:

| Case | Eval tok/s | Wall tok/s | Prompt tok/s | Draft acceptance |
| --- | ---: | ---: | ---: | ---: |
| `draft-mtp n=3, t28, ub1024` | 37.94 | 36.54 | 128.18 | 0.6928 |
| `no MTP, t28, ub1024` | 26.31 | 25.77 | 159.01 | 0.0000 |

MTP improved wall throughput by about 42% on this prompt. Qwopus Q5_K_M is slower than the local Qwen MXFP4 profile, but it is a coder fine-tune and should be evaluated on coding-agent quality as well as raw tok/s.

Retune later if throughput or acceptance looks weak. The first things to try would be `--spec-draft-n-max 2`, `threads=24`, and `ubatch=1536`, because those were competitive on the other Qwen-family GGUFs.

## Hermes

Add saved provider only:

```text
scripts\hermes\add-hermes-qwopus-coder-custom-provider.bat
```

Switch active default:

```text
scripts\hermes\configure-hermes-qwopus-coder-local-provider.bat
```

Verify after the server is running:

```powershell
Invoke-RestMethod http://127.0.0.1:8004/v1/models
```

## Agent Notes

1. This is an MTP GGUF. Keep `--spec-type draft-mtp` enabled unless a local benchmark proves otherwise.
2. The default provider uses port `8004` to avoid renaming or clobbering the existing Qwen provider on port `8001`.
3. Hermes sees only an OpenAI-compatible endpoint; start the Qwopus server before selecting the Qwopus provider.
4. The model card emphasizes thinking-off coding-agent use, so do not enable reasoning by default for Hermes.
