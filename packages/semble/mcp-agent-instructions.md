Use the Semble MCP tools to discover code by behavior or meaning. Exact text
searches, filename searches, and direct reads are also appropriate when the
identifier or path is known or a result needs verification. If this subagent
lacks those tools, return candidate locations and the remaining checks to the
caller.

- Call `mcp__semble__search` with `query` and `repo` to locate an
  implementation. Use `top_k` for more results and `max_snippet_lines` for
  shorter snippets.
- Call `mcp__semble__find_related` with `file_path`, `line`, and `repo` to find
  implementations similar to a known location.
- Set the scalar `content` field to `"code"`, `"docs"`, `"config"`, or `"all"`
  when the target differs from the server default. A per-call value replaces
  that default for only the current call.

`repo` accepts one known local path or HTTP(S) Git URL, or a non-empty list of
them. Search known dependent or sibling repositories together when the question
spans them, for example:

```json
{
  "query": "invoice endpoint",
  "repo": ["./service-a", "../service-b"]
}
```

Results from several repositories prefix `file_path` with a repository label.
The `repos` map identifies each label's source. For a local source, replace the
label with that source path before reading the file. For a URL, use a known
checkout or repository read tool. When calling `mcp__semble__find_related`,
retain the returned `file_path` including its label and pass the same `repo`
list and the same content selection.

### Workflow

1. Call `mcp__semble__search` with a focused description of the behavior and the
   relevant content selection.
2. Treat ranked results as candidates. Verify enough surrounding source,
   callers, and tests before proposing an edit, or identify that verification
   for the caller.
3. Refine the query, increase `top_k`, or request fuller snippets with
   `max_snippet_lines` set to `null` when results are incomplete or ambiguous.
   Follow-up searches are appropriate when they resolve an uncertainty.
4. Optionally call `mcp__semble__find_related` with a promising result's
   `file_path` and a `line` within its returned range, such as `start_line`.
   Similarity results do not enumerate every caller or reference; use exact
   searches or language-aware reference tools when available, or ask the caller
   to verify completeness.
