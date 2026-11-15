# Template: report (chat, after the rebuild succeeded)

```
**{Feature} is live**

{What changed, in words, and on which host.} {How to see it work, in words.}
{Only if a host still needs it: "Run the same rebuild on {other host} to get it there."}
```

Optional pushback blockquote: something the user should know that changes a later decision.

```
**Appendix**
- **Changed:** {path} — {what}
- **Check:** {command or action}
- **Generation:** {number from the commit message}
```

Then, only if the run found one, the proposed learning:

```
**Questions**
🟡 Save this to {host doc | repo CLAUDE.md gotchas}? "{exact line}"
```
