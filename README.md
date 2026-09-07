# BACR Patient Triage System

Flutter Web frontend (Supabase-ready, no backend yet).

**Live:** https://hayprime1-pro.github.io/triage-navigator/

## What it does

- Guided triage: Functional Domains + Risk Flags + Red Flag → Complexity, Risk, Pathway, Next Step
- 5 connected pages: Triage, Result, History, Rules, Settings
- Light / dark / system theme (persisted on-device)
- History + routing rules persist on-device (SharedPreferences); search + copy-as-JSON export
- Responsive (320px phones → desktop), accessible (48px targets, screen-reader labels, live result announcements)

## Dev

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d web-server --web-port 8081
```

Builds + deploys via GitHub Actions (`.github/workflows/pages.yml`) on every push to `main`.
