# My House iOS (event demo)

The app display name is My House; the agent is @House. The Xcode project, scheme, source folders and bundle identifier retain Kollektiv for compatibility.

1. `brew install xcodegen`
2. `cp Secrets.example.xcconfig Secrets.xcconfig` and paste your Anthropic API key.
3. `xcodegen generate && open Kollektiv.xcodeproj`
4. Run on the iPhone 17 simulator.

Demo mode: in-memory data seeded relative to today. Use the "Demo:" menu to switch between Kristian, Sam and Mia.

Journey A: as Kristian, tap Ask the house and send "mark me away for dinner Fri–Sun and ask someone to take my Saturday kitchen clean". Switch to Sam and tap "I can take it".

Journey C: "@House I'll cook vegetable curry on Thursday", then "@House who's eating Thursday?".

Scope and cuts: see `docs/superpowers/specs/2026-09-14-kollektiv-event-demo-design.md`.
