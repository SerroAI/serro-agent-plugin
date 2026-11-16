**Serro plugin installed.** Add the Serro MCP server and sign in, since a Hermes plugin can't bring its own:

```sh
hermes mcp add serro --url https://mcp.serro.ai/mcp --auth oauth
```

Sign in again later with `hermes mcp login serro`. If you didn't enable the plugin during install, run `hermes plugins enable serro`.

The commands are `/serro:program`, `/serro:sync` and `/serro:handoff`, in the CLI, TUI and Desktop. Messaging platforms don't list them.
