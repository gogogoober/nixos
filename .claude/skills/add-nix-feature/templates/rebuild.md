# Template: rebuild handover (chat, the phase 6 gate)

```
**Ready to rebuild**

{One or two sentences: just test passed on every host; what the rebuild will switch on.}
{Only for a new unit wanted by multi-user.target: "Reboot once after this, since an ordering
cycle only shows up on a real boot."}
```

Then the command alone in a bash block, message in the repo's commit style (short, lowercase,
semicolons between parts, no generation number; the recipe adds it):

```bash
just rebuild "{message}"
```

Rules
- One command. Extra flags only when a known gotcha applies (`just extra=--install-bootloader`).
