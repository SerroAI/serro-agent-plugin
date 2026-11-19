#!/bin/sh
# Checks the OpenAI directory package against the rules its submission enforces.
set -eu
cd "$(dirname "$0")/.."
sh scripts/build-codex-directory >/dev/null
python3 - <<'PY'
import json
import zipfile

z = zipfile.ZipFile("dist/serro-codex-directory.zip")
names = z.namelist()
fails = []


def check(ok, what):
    print(("ok    " if ok else "FAIL  ") + what)
    if not ok:
        fails.append(what)


check(not any(n.startswith(("hooks/", "scripts/")) for n in names), "no hooks or scripts")
m = json.loads(z.read(".codex-plugin/plugin.json"))
i = m["interface"]
check(len(i["displayName"]) <= 30 and len(i["shortDescription"]) <= 30, "name and subtitle <= 30 chars")
check(0 < len(i["longDescription"]) <= 4000, "long description <= 4000 chars")
check("hook" not in i["longDescription"].lower(), "long description doesn't promise hooks")
check(all(i.get(k, "").startswith("https://") for k in ("websiteURL", "supportURL", "privacyPolicyURL", "termsOfServiceURL")), "all four listing URLs")
check(len(i["capabilities"]) <= 20 and all(len(c) <= 120 for c in i["capabilities"]), "capabilities within limits")
check(all(len(p) <= 128 for p in i.get("defaultPrompt", [])) and len(i.get("defaultPrompt", [])) <= 3, "starter prompts within limits")
check(f"{i['logo'].lstrip('./')}" in names and i["composerIcon"].lstrip("./") in names, "icons included")
servers = json.loads(z.read(".mcp.json"))["mcpServers"]
check(len(servers) == 1, "exactly one MCP server")
cases = m["extensions"]["com.openai"]["review"]["test_cases"]
check(len(cases["positive"]) == 5 and len(cases["negative"]) == 3, "5 positive and 3 negative test cases")
check(all(c.get("tools_triggered") and c.get("expected_behavior") for c in cases["positive"]), "positive cases name tools and behavior")
check("README.md" in names and "hook" not in z.read("README.md").decode().split("This edition")[0].lower(), "README without hooks")
raise SystemExit(1 if fails else 0)
PY
