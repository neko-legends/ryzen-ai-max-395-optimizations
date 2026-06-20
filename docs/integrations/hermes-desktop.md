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
scripts\start-qwen36-35b-a3b-mxfp4-mtp-262k.bat
```

Command line:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-qwen36-35b-a3b-mxfp4-mtp-262k.ps1
```

The older `scripts\start-qwen36-35b-a3b-mtp-262k.bat` launcher starts the `UD-Q4_K_XL` profile. Use the MXFP4 launcher when `Qwen3.6-35B-A3B-MXFP4_MOE.gguf` is present.

Default endpoint:

```text
http://127.0.0.1:8001/v1
```

## Configure Hermes

There are two different actions:

- Add the model to Hermes' saved custom providers.
- Make it the active default model.

The quick dropdown may not show a newly saved local provider until Hermes Desktop is restarted and the model is selected through `Edit Models...`.

## Add To The Model Picker

This does not change your active GPT/OpenAI Codex model. It only registers the local endpoint as a saved custom provider.

Double-click:

```text
scripts\add-hermes-qwen-mxfp4-custom-provider.bat
```

Command line:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\add-hermes-qwen-custom-provider.ps1 `
  -Name "Qwen3.6 35B-A3B MXFP4 MTP 262K"
```

This adds:

```yaml
custom_providers:
- name: Qwen3.6 35B-A3B MXFP4 MTP 262K
  base_url: http://127.0.0.1:8001/v1
  model: local
  api_mode: chat_completions
  models:
    local:
      context_length: 262144
```

Then:

1. Start the Qwen server.
2. Restart Hermes Desktop.
3. Open the dropdown shown in the screenshot.
4. Click `Edit Models...`.
5. Choose `Qwen3.6 35B-A3B MXFP4 MTP 262K` from the custom/saved provider list.

## Make It The Active Default

This changes Hermes' default model provider. Run it when you want Hermes Desktop to use the local Qwen server by default.

Double-click:

```text
scripts\configure-hermes-qwen-mxfp4-local-provider.bat
```

Command line:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-hermes-qwen-local-provider.ps1 `
  -Name "Qwen3.6 35B-A3B MXFP4 MTP 262K"
```

This backs up `%LOCALAPPDATA%\hermes\config.yaml` before changing it.

It also registers the saved custom provider, then applies:

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

1. Add the saved provider with `add-hermes-qwen-mxfp4-custom-provider.bat`, or make it active with `configure-hermes-qwen-mxfp4-local-provider.bat`.
2. Start the Qwen server with `start-qwen36-35b-a3b-mxfp4-mtp-262k.bat`.
3. Launch or restart Hermes Desktop.
4. Select the saved provider through `Edit Models...` if you only added it.
5. Send a small prompt first to verify the local endpoint is live.

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
- For the MXFP4_MOE GGUF, the server should be started with the 262K profile in `scripts/start-qwen36-35b-a3b-mxfp4-mtp-262k.ps1`.
- Hermes only sees an OpenAI-compatible endpoint. It does not know whether the backend model is `UD-Q4_K_XL` or `MXFP4_MOE`; use the provider name to keep the UI clear.
