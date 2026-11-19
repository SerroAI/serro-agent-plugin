# Catalog listing files

Files that catalogs take as uploads rather than reading this repo directly.

- `codex-directory/`: OpenAI's plugin directory (ChatGPT and Codex) rejects packages with hooks. `sh scripts/build-codex-directory` builds `dist/serro-codex-directory.zip` from `clients/codex` without its hooks. It also adds the long description, capabilities and review test cases from `plugin.overlay.json`, and this folder's README. Upload the zip at platform.openai.com/plugins, choosing **With MCP**. `tests/codex-directory.sh` checks it against the submission limits. Before submitting, add `review.demo_recording_url` to the overlay. Then enter a reviewer account in the dashboard: one without MFA, with sample programs and Agent Exchange turned on.
- `mcp-registry/server.json`: the Serro MCP server's entry in the official MCP Registry, published with `mcp-publisher publish` from this folder. The `ai.serro/` namespace needs the publisher's DNS TXT record at the serro.ai apex.
