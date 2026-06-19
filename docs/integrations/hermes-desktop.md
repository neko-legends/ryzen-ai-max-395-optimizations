# Hermes Desktop Local Provider

Hermes Desktop / Hermes Agent can use the tuned Qwen llama.cpp server as a local OpenAI-compatible provider.

The local Hermes install confirms this path:

- Main model config lives in `%LOCALAPPDATA%\hermes\config.yaml`.
- Hermes reads `model.provider`, `model.base_url`, `model.default`, `model.api_key`, `model.api_mode`, and `model.context_length`.
- `provider: custom` with `model.base_url` routes to an OpenAI-compatible endpoint.
- For local endpoints without auth, Hermes supplies a placeholder API key internally (`no-key-required`), so no real key is needed.
- The GUI model assignment path also explicitly supports custom/local endpoint `base_url`.

## Start The Model Server

Double-click:

```text
scripts\start-qwen36-35b-a3b-mtp-262k.bat
```

Command line:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-qwen36-35b-a3b-mtp-262k.ps1
```

Default endpoint:

```text
http://127.0.0.1:8001/v1
```

## Configure Hermes

This changes Hermes' default model provider. Run it when you want Hermes Desktop to use the local Qwen server by default.

Double-click:

```text
scripts\configure-hermes-qwen-local-provider.bat
```

Command line:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-hermes-qwen-local-provider.ps1
```

This backs up `%LOCALAPPDATA%\hermes\config.yaml` before changing it.

It applies:

```yaml
model:
  provider: custom
  base_url: http://127.0.0.1:8001/v1
  default: local
  context_length: 262144
  api_mode: chat_completions
```

Equivalent Hermes CLI commands:

```powershell
$py = "$env:LOCALAPPDATA\hermes\hermes-agent\venv\Scripts\python.exe"
& $py -m hermes_cli.main config set model.provider custom
& $py -m hermes_cli.main config set model.base_url http://127.0.0.1:8001/v1
& $py -m hermes_cli.main config set model.default local
& $py -m hermes_cli.main config set model.context_length 262144
& $py -m hermes_cli.main config set model.api_mode chat_completions
```

## Usage Order

1. Start the Qwen server with `start-qwen36-35b-a3b-mtp-262k.bat`.
2. Configure Hermes once with `configure-hermes-qwen-local-provider.bat`.
3. Launch or restart Hermes Desktop.
4. Send a small prompt first to verify the local endpoint is live.

If Hermes was already open, restart it after changing config so the desktop app reloads the model settings.

If the Qwen server is not running, Hermes' local provider calls will fail until the server is started again.

## Verify The Endpoint

With the server running:

```powershell
Invoke-RestMethod http://127.0.0.1:8001/v1/models
```

Minimal chat request:

```powershell
$body = @{
  model = "local"
  messages = @(@{ role = "user"; content = "Reply with only: OK" })
  max_tokens = 8
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Uri http://127.0.0.1:8001/v1/chat/completions `
  -Method Post `
  -ContentType "application/json" `
  -Body $body
```

## Undo

The configure script prints the backup path it created. Restore that file over:

```text
%LOCALAPPDATA%\hermes\config.yaml
```

Or use Hermes' model picker/config commands to select a cloud provider again.

## Notes For Agents

- Do not put a real OpenAI key in this local endpoint config.
- Keep `provider: custom`; `model.base_url` is the routing signal for Hermes.
- `model.default: local` is accepted by llama.cpp server requests. If a future server enforces model IDs, use the model id returned by `/v1/models`.
- Start the model server before Hermes attempts to use the provider.
- For this Qwen model, the server should be started with the 262K profile in `scripts/start-qwen36-35b-a3b-mtp-262k.ps1`.
