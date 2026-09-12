Use `semble search` to discover code by behavior or meaning. Use exact text
searches, filename searches, and direct reads when you know the identifier or
path or need to verify a result.

```bash
semble search "authentication flow" ./my-project --max-snippet-lines 10
semble search "save_pretrained" ./my-project
semble search "save model to disk" ./my-project --top-k 10
```

Results are cached automatically on first run and invalidated when files change.

`--content` selects one or more categories to search:

```bash
semble search "deployment guide" ./my-project --content docs
semble search "database host port" ./my-project --content config
semble search "authentication" ./my-project --content code docs
semble search "authentication" ./my-project --content all
```

Use `semble find-related` to discover code similar to a known location. Pass the
`file_path` and `line` from a prior search result:

```bash
semble find-related src/auth.py 42 ./my-project
```

The path defaults to the current directory when omitted; Git URLs are accepted.

Pass several known paths or URLs when the question spans related repositories:

```bash
semble search "invoice endpoint" ./service-a ../service-b
```

Results from several repositories prefix `file_path` with a repository label.
The `repos` map identifies each label's source. For a local source, replace the
label with that source path before reading the file. For a URL, use a known
checkout or repository read tool. When calling `semble find-related`, retain the
returned `file_path` including its label and pass the same repository paths and
content selection.

### Workflow

1. Search with a focused description of the behavior. Pass `--content` when
   searching beyond code: `docs`, `config`, several categories such as
   `code docs`, or `all`.
2. Treat ranked results as candidates. Read enough surrounding source, callers,
   and tests to verify their relevance before proposing an edit.
3. Refine the query, expand the snippets or result count, or use exact text and
   filename searches when results are incomplete or ambiguous. Search known
   dependent or sibling repositories together when relevant.
4. Optionally use `semble find-related` with a promising result's `file_path`
   and a `line` within its returned range, such as `start_line`, to discover
   similar implementations. Similarity results do not enumerate every caller or
   reference; use exact searches or language-aware reference tools when
   completeness matters.
