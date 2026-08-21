# Contributing

OmaPanel follows three rules: use Quattro's shared UI and theme primitives,
collect without privilege, and delegate mutations to canonical system tools.

Before submitting a change:

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell OmaPanel.qml
shellcheck scripts/omapanel-backend setup bin/omapanel tests/run
./tests/run
```

New action adapters must include target validation, a dry-run specification,
an impact explanation, fixture coverage, and an existing authoritative
workflow. Tests must never execute destructive actions.

New Doctor checks must have a timeout, explicit unavailable/failure behavior,
a privacy-reviewed report summary, and fixtures proving that one provider
cannot discard other results. Never construct a shareable report from the
internal detail field.

When reporting a defect, include the Omarchy version, theme, display size, the
affected page/provider, and the sanitized report when available. Never include
sudo output, authentication material, or private journal contents.
