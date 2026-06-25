# Benchmark prompts

These files are deterministic prompt fixtures copied from
`C:\git\nvidia-local-llm-profiles\benchmarks\prompts` for comparing local model
profiles. Keeping the prompt text in this repo makes short-context reruns
and long-context reruns comparable across quantizations, runtimes, and the
NVIDIA baseline repo.

## book-context-10k.txt

- Generator: `scripts/benchmarks/bench-openai-chat-endpoint.ps1`
- Style: `BookContext`
- Target: `10000` prompt tokens
- Characters: `42940`
- SHA256: `785c5b31d1ce77612431b1289c0a097ed51ab1a6d4a07bccfb7a70f59df55f94`
- Used for: Qwopus Q4_K_M and Qwopus Q5_K_M 10k reference comparisons

## book-context-200k.txt

- Generator: `scripts/benchmarks/bench-openai-chat-endpoint.ps1`
- Style: `BookContext`
- Target: `200000` prompt tokens
- Characters: `840403`
- SHA256: `a794ca243983eb3387bec6728db4b0c72a99ee2a98cfee7223269708e4ae228c`
- Used for: 200k reference comparisons across Qwopus, Unsloth 35B, and NVIDIA NVFP4 runs

Regenerate from the NVIDIA baseline repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\benchmarks\bench-openai-chat-endpoint.ps1 `
  -PromptStyle BookContext `
  -TargetPromptTokens 10000 `
  -PromptOutFile benchmarks\prompts\book-context-10k.txt `
  -PromptOnly
```

Regenerate the 200k fixture from the NVIDIA baseline repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\benchmarks\bench-openai-chat-endpoint.ps1 `
  -PromptStyle BookContext `
  -TargetPromptTokens 200000 `
  -PromptOutFile benchmarks\prompts\book-context-200k.txt `
  -PromptOnly
```

Benchmark from the saved prompt in the NVIDIA baseline repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\benchmarks\bench-openai-chat-endpoint.ps1 `
  -BaseUrl http://127.0.0.1:39182/v1 `
  -Model qwopus3.6-27b-coder-mtp-q5-k-m `
  -PromptFile benchmarks\prompts\book-context-10k.txt `
  -PromptStyle BookContext `
  -TargetPromptTokens 10000 `
  -MaxTokens 1024
```
