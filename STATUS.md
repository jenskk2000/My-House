# My House — paused 15 September 2026

SwiftUI prototype for shared living: meals, chores, calendar and group chat with @House. Built around the idea of Claude Tag for your shared house.

## Current state
- Working illustrated house navigation, dinner attendance, chores, weekly overview and agent volunteer requests.
- Latest fixes: explicit clarification replies, retry conversation/proposal retention, strict date validation, keyboard dismissal and wrapping chore labels.
- Last verification: 27 local tests passed; Home and Chat checked in simulator. Live API tests were excluded from that run.
- Current implemented design is the blue/yellow cartoon house. New concepts A Sunday Club, B House Party and C Little World are exploration only; no direction selected by user.
- Code remains uncommitted on `main`, following `efcb7dd`. Preserve the working tree and untracked files; nothing reset, stashed or deleted for this pause.

## Files
- Spec: `docs/kollektiv-mvp/SPEC.md` and `SPEC.html`.
- New mockups and prompts: `docs/design-explorations/2026-09-15/`.
- Screenshots, journey and combined PNG: `/Users/jenskristian/Desktop/My House/`.
- X draft previously prepared with Home, Dinner and volunteer-request screenshots. Safari left untouched during shutdown; current draft/publishing state not reverified. Last prepared wording below ("today" referred to the event on 14 September):

> Built My House at today’s Build with Claude event in Oslo.
>
> I want it to feel like Claude Tag, but for your shared house. Tag @House to update dinner plans or find a volunteer for a chore.
>
> An iOS prototype: playful on the surface, agents handling the admin.

## Shutdown and resume
- Project iPhone 17 simulator shut down; localhost:3200 was already not listening. No active xcodebuild process found. Inactive simulator browser tab closed.
- Source, assets, installed app and build caches kept. In-memory demo data resets at relaunch.
- Safari and unrelated applications left alone. Static spec tab may remain open.
- To resume, open `ios/Kollektiv.xcodeproj`, select scheme Kollektiv and an iPhone simulator, then Run. `ios/project.yml` is the XcodeGen source.
- API key is currently injected from ignored `ios/Secrets.xcconfig` into the app; do not publish/distribute a build containing it.

## Next decisions
1. Select/refine a visual direction before another redesign.
2. Add authenticated backend agent calls and persistent shared household data; test one volunteer journey across two phones.
3. Notifications, accessibility testing at larger text sizes, then narrow App Intents for attendance and chore cover.
