# `ominty inspect --json` schema

The machine-readable installation audit. This is the contract an installing
agent depends on; treat changes to it as a compatibility event and check
`schema_version`.

```sh
ominty inspect --json
ominty inspect --json --layer desktop   # narrow to specific layers
ominty inspect                          # human-readable
```

Read-only, and never requires `sudo`. Exit code is `0` when
`summary.ready` is true, `1` otherwise — that reflects *blocking* findings
only, so it is safe to use in scripts.

---

## Top level

| Key | Type | Notes |
| --- | --- | --- |
| `schema_version` | int | Currently `1`. |
| `tool` | string | Always `"ominty"`. |
| `platform` | object | See below. |
| `hardware` | object | `arch`, `cpu`, `gpu`. |
| `session` | object | `type`, `desktop`, `wayland_display`. |
| `privilege` | object | `sudo` (passwordless?), `required`. |
| `layers` | object | Keyed by layer id. |
| `apt` | object | `sources`, `pins`, `backports_enabled`, `obs_danklinux_enabled`, `obs_dms_enabled`. |
| `configs` | object | Keyed by config name. |
| `choices` | array | See "Choice points". |
| `findings` | array | Every check. |
| `summary` | object | `ready`, `blocking`, `warnings`, `required_choices`, `counts`. |

---

## `platform`

```json
{
  "id": "debian",
  "distro_id": "linuxmint",
  "pretty_name": "Linux Mint 7",
  "version_id": "7",
  "codename": "gigi",
  "is_lmde": true,
  "supported": true
}
```

`id` is the platform family: `debian`, `void`, or `unknown`.

`supported` is true when `codename` is one of `trixie`, `faye` or `gigi`.
`gigi` is Debian 13's codename, which some LMDE 7 images report instead of
LMDE's own `faye`. Both are accepted.

A non-Debian-family distribution is a **blocking** finding. An untested
codename is only a warning, because it is a judgement call for the user.

---

## `layers`

```json
"layers": {
  "desktop": {
    "id": "desktop",
    "label": "Niri + DMS desktop",
    "description": "Compositor, shell, theming, audio and portals.",
    "provisioned": true,
    "packages": [
      {
        "name": "dms",
        "state": "installed",
        "version": "1.6.2db1",
        "source": "obs",
        "required": true
      },
      {
        "name": "niri",
        "state": "missing",
        "version": null,
        "source": "local",
        "required": true,
        "reason": "Not installed; ships as a local .deb in packages/.",
        "fix": "Run install.sh to install the bundled .deb."
      }
    ],
    "satisfied": false,
    "missing": ["niri"]
  }
}
```

`source` is one of:

| Value | Meaning |
| --- | --- |
| `apt` | In the Debian/Ubuntu archive. |
| `obs` | From the AvengeMedia Open Build Service. Needs `install.sh` to add the sources. |
| `local` | A `.deb` bundled in `packages/`. |

`provisioned` says whether `install.sh` installs the layer today. A layer with
`provisioned: false` reports a **warning**, never a blocking finding — do not
tell the user a layer is broken when it simply is not offered yet.

`reason` and `fix` appear only on `missing` packages. Always pass `reason` on
to the user: it distinguishes an uninstalled package from an unavailable one.

---

## `findings`

```json
{
  "id": "layer.desktop",
  "status": "warn",
  "severity": "info",
  "message": "Layer 'Niri + DMS desktop' is missing 1 required package(s): niri.",
  "fix": "Run install.sh, or install the missing packages individually."
}
```

| `status` | Meaning |
| --- | --- |
| `pass` | Check succeeded. |
| `warn` | Usable, but the user should know. |
| `fail` | Something is wrong. |

`severity` decides whether a `fail` blocks:

- `blocking` → do not install. Report and stop.
- `info` → informational only.

Only failures with `severity: "blocking"` appear in `summary.blocking`.

Finding ids are stable and namespaced: `platform`, `hardware.*`, `layer.*`,
`config.*`, `plugin.*`, `session`, `session.dms`, `choice.*`.

---

## `summary`

```json
{
  "ready": false,
  "blocking": ["config.ominty_cli", "config.ominty_hook"],
  "warnings": ["layer.cli", "choice.llm.provider"],
  "required_choices": ["llm.provider", "session.default", "config.migration"],
  "counts": {"pass": 6, "warn": 12, "fail": 2}
}
```

`ready` is `not summary.blocking`.

**Outstanding choices do not affect `ready`.** A question waiting for an answer
is not a failure. Read `required_choices` separately and ask.

---

## Choice points

```json
{
  "id": "llm.provider",
  "question": "Which LLM should power the AI actions (Super+A), or should AI be left unconfigured?",
  "required": true,
  "multiple": false,
  "rationale": "AI actions need a provider before the configuration can be written...",
  "default": "ollama",
  "detected": {
    "configured_provider": "pi",
    "config_file": "/home/user/.config/ominty/ai.toml",
    "provider_status": {
      "ollama": {"state": "unavailable", "detail": "ollama binary not found in PATH"},
      "pi": {"state": "available", "detail": ""}
    }
  },
  "options": [
    {
      "value": "ollama",
      "label": "Ollama (local models)",
      "detail": "Runs models on this machine...",
      "available": false,
      "unavailable_reason": "ollama binary not found in PATH"
    }
  ]
}
```

`multiple` distinguishes a multi-select (`layers`, where `default` is a list)
from a single-select.

`available` is probed live. When the AI layer cannot be probed at all, options
stay `available: true` rather than being wrongly reported unusable — an
unavailable-looking option that actually works is worse than a missing detail.

### Current choices

| id | Required | Question |
| --- | --- | --- |
| `llm.provider` | yes | Which LLM powers the AI actions, or none? |
| `layers` | no | Which optional groups to install (multi-select). |
| `session.default` | yes | Make Niri the default login session, or leave it? |
| `config.migration` | yes | Replace existing configuration, or keep it? |
| `plugins.dms` | no | Install the third-party DMS plugins? |

---

## `--layer`

Restricts the report to the named layers. Findings not scoped to a layer
(`platform`, `hardware`, `session`, `config.*`, `plugin.*`, `choice.*`) are
global and are always kept, because they affect any install. Choice points are
also always kept.

An unknown layer id is an error, and the message lists the valid ids.

---

## Stability

The schema changes only with a `schema_version` bump. Fields may be **added**
within a version; agents should ignore keys they do not recognise rather than
failing.