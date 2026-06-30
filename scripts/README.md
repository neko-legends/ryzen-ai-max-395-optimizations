# Scripts

Scripts are grouped by runtime and integration:

- `hermes/`: Hermes Desktop custom-provider helpers.
- `localai/qwen36-35b-a3b-mtp-gguf/`: AMD HIP/ROCm llama.cpp launch and benchmark scripts for the Qwen3.6 35B A3B MTP GGUF family.
- `localai/qwopus36-35b-a3b-coder-mtp-gguf/`: downloader, installer, and launcher for Qwopus3.6 35B A3B Coder MTP Q5_K_M.
- `localai/ornith-1.0-35b-gguf/`: downloader and benchmark scripts for DeepReinforce Ornith 1.0 35B GGUF Q4_K_M and Q5_K_M.

Shared benchmark prompt fixtures live under `..\benchmarks\prompts`. They are copied from `C:\git\nvidia-local-llm-profiles\benchmarks\prompts` so the Ryzen runs can use the same short and 200K-style BookContext prompts as the NVIDIA baseline repo.

## Local Model Locations

This repo does not store model weights. Keep large GGUF files outside git and pass `-ModelPath` when a model lives somewhere custom.

Current scripts search these locations by default:

- `%USERPROFILE%\Downloads`
- `%USERPROFILE%\.cache\huggingface\hub\<model repo>\snapshots`

On this machine, the currently installed GGUFs are in the Hugging Face cache:

- `%USERPROFILE%\.cache\huggingface\hub\models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF\snapshots\...\Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf`
- `%USERPROFILE%\.cache\huggingface\hub\models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF\snapshots\...\Qwen3.6-35B-A3B-MXFP4_MOE.gguf`
- `%USERPROFILE%\.cache\huggingface\hub\models--Jackrong--Qwopus3.6-35B-A3B-Coder-MTP-GGUF\snapshots\manual\Qwopus3.6-35B-A3B-Coder-MTP-Q5_K_M.gguf`
- `%USERPROFILE%\.cache\huggingface\hub\models--unsloth--Step-3.7-Flash-GGUF\snapshots\...\MXFP4_MOE\Step-3.7-Flash-MXFP4_MOE-*.gguf`

The local llama.cpp runtime used by these scripts is:

```text
%USERPROFILE%\.unsloth\llama.cpp\build\bin\Release\llama-server.exe
```

Use the Hugging Face cache as the default install target unless a separate app requires a stable flat folder. It avoids duplicating 20+ GB model files and matches the existing Qwen setup.

The Ornith downloader prefers `hf` or `huggingface-cli` when installed. If neither is available, it streams the public file directly to:

```text
%USERPROFILE%\.cache\huggingface\hub\models--deepreinforce-ai--Ornith-1.0-35B-GGUF\snapshots\manual
```

`ornith-1.0-35b-Q5_K_M.gguf` is about `23.0 GiB`.
`ornith-1.0-35b-Q4_K_M.gguf` is smaller and is the better apples-to-apples comparison when the rest of the local GGUF rows are Q4-class.

The Qwopus downloader uses the same strategy and streams the public Q5_K_M file to:

```text
%USERPROFILE%\.cache\huggingface\hub\models--Jackrong--Qwopus3.6-35B-A3B-Coder-MTP-GGUF\snapshots\manual
```

`Qwopus3.6-35B-A3B-Coder-MTP-Q5_K_M.gguf` is about `23.60 GiB`.

The Ornith benchmark scripts accept `-PromptFile`, `-PromptStyle`, and `-TargetPromptTokens` for long-context baselines. The copied `book-context-200k.txt` fixture is a target-200K prompt, but Ornith Q4_K_M and Q5_K_M counted it as `174588` prompt tokens in the 262K benchmark runs. Treat the full-request wall time from that run as cold one-shot prefill latency, not steady interactive coding throughput.
