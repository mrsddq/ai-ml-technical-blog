# Technical writing runbook

This repository contains Markdown articles and drafts. It has no deployed blog
service or application test suite.

## Review an article

1. Start with the article index in the [README](../README.md).
2. Check commands and engineering claims against the linked source repository.
3. State whether evidence comes from a test, a deployment or a measured experiment.
4. Follow the [publishing checklist](PUBLISHING_CHECKLIST.md).

```bash
make verify
```

This checks whitespace in the working diff. It does not execute article commands
or validate external websites. Publication through a hosting service is separate.
