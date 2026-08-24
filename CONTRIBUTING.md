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

New direct settings must call a canonical Omarchy command, validate values
against current state or a fixed allowlist, return structured success, and
offer a reversible previous value in the UI. A test fixture must prove both
the accepted argv and rejection of unsupported input. Never infer state by
calling a command whose default behavior toggles it.

New Doctor checks must have a timeout, explicit unavailable/failure behavior,
a privacy-reviewed report summary, and fixtures proving that one provider
cannot discard other results. Never construct a shareable report from the
internal detail field.

New Storage providers must be read-only, failure-isolated, timeout-bounded
where external services are involved, and must omit persistent disk
identifiers. Directory operations must accept canonical readable directories
as argv values, never shell text, and must preserve cancellation through every
child process.

When reporting a defect, include the Omarchy version, theme, display size, the
affected page/provider, and the sanitized report when available. Never include
sudo output, authentication material, or private journal contents.
