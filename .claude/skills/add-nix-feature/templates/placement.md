# Template: placement card (chat, the phase 4 gate)

Spoken part, one paragraph:

```
**Where {feature} goes**

{Kind: setting, module change, or new module} {in which module or host, in words}. {Why there:
which rule decides it, in words}. {The option it uses, in words, or "no option exists, so a
small mechanism of our own".} {Hosts that get it.}
```

Optional pushback blockquote when the request fights the host's goal or a dead end.

Appendix, literal strings:

```
**Appendix**
- **Option:** {services.x.enable | none}
- **Edit:** {path} — {what changes}
- **Edit:** {path} — {what changes}
- **New file:** {path} — {one concern}
- **Host switch:** hosts/{host}/default.nix — {modules.x.enable = true}
- **Check after rebuild:** {command}
```

Rules
- Every file the edit will touch is listed; nothing else may change.
- Kind is exactly one of the three words.
