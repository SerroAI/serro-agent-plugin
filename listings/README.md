# Catalog listing files

Files that catalogs take as uploads rather than reading this repo directly.

## OpenAI plugin directory (`codex-directory/`)

The directory (ChatGPT and Codex) rejects packages with hooks. `sh scripts/build-codex-directory` builds `dist/serro-codex-directory.zip` from `clients/codex` without its hooks. It also adds the long description, capabilities and review test cases from `plugin.overlay.json`, and this folder's README. `tests/codex-directory.sh` checks the zip against the submission limits.

To submit, in this order:

1. Complete business verification for Serro in the OpenAI Platform org settings. Every submission needs a verified identity.
2. Verify the MCP server's domain. Put the token the dashboard shows at `https://mcp.serro.ai/.well-known/openai-apps-challenge`, then choose **Verify Domain**. Without it the submission fails with `domain_verification_required`.
3. Add `review.demo_recording_url` to `plugin.overlay.json`, then build the zip. The build merges the overlay, so a zip built before this edit has no demo link. The build warns while the link is missing.
4. Upload the zip at platform.openai.com/plugins, choosing **With MCP**.
5. In the dashboard, enter a reviewer account: one without MFA, with sample programs and Agent Exchange turned on.

## MCP Registry (`mcp-registry/server.json`)

The Serro MCP server's entry in the official MCP Registry, under the `ai.serro/` namespace. From `listings/mcp-registry`:

1. Generate an Ed25519 key pair and add the TXT record `mcp-publisher` asks for at the serro.ai apex. On macOS, Ed25519 needs OpenSSL 3.
2. Once the record has propagated, run `mcp-publisher login dns --domain serro.ai` with the matching private key. The TXT record proves the domain, and this login authenticates the CLI.
3. Run `mcp-publisher publish`. Each published `version` is final, so bump it for every change.
