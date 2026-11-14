# Native playback audit — 15 November 2026

Tested against the installed Flux v4.07 kit in Studio. These are measured checks,
not a claim that every possible fixture, preset, or multiplayer condition is covered.

## Fixed and measured

- Removed the direct emitter/motor renderer and the single-profile client relay.
- Native renderer on/off test: 371 channel checks each direction, zero failures
  on a clean test: profile 16, wash 8, JDC1 288, line 58, follow spotlight 1.
- Fade interrupted by Off: all washes remained off after the original fade ended.
- Concurrent line color and intensity fades: full output reached red; neither
  attribute cancelled the other.
- Native wash `bounce 11` followed by Off: effect output changed during playback,
  then both lens transparency and light output remained off at 2 and 3.7 seconds.
- Stop during a fade: transparency stayed at 0.758075 at both follow-up samples.
  A subsequent native panel On command returned transparency to zero.
- The native effects, macro, position and blackout command formats were captured
  from actual panel actions. No guessed numeric native fade-speed parameter is used.
- Source/JavaScript contract checks passed. They supplement, not replace, Studio tests.
- Ran the actual `Underscores` show with its audio through 37 seconds. The saved
  wash position reached pan 145° / tilt -25°. Native effect output varied, and
  at 37 seconds the wash lens was fully transparent and its light brightness
  was zero after the authored 35.625-second Off cue. No playback errors occurred.

## Additional fixes

- Current saved effect/position existence is checked before playback.
- Cue errors are surfaced, and an authorized client's native-render failure stops the show.
- Audio failure or timeout prevents the show from silently starting without audio.
- Natural show completion clears the show's playback work.
- Stop invalidates in-flight play requests so an older validation request cannot restart a show.

## Known limits

- Flux's Kill control sends blackout commands. Native macro counter changes did
  not cancel a delayed test step. Timed, delayed, and effect-triggering macros
  are therefore refused before playback; they are not claimed to be fixed.
- Pyrotechnics have no verified native playback command yet and are refused.
- Native position movement uses Flux's configured movement behavior. Immediate
  cancellation of a native position's own motor travel has not been verified.
- Late-joining clients and synchronization between multiple real clients have
  not been validated. The current rig contains five fixture types, not every
  type in Flux's catalog.
- The custom Fixture Focus plugin still logs a client-side DataStore access error.
  This audit does not claim that separate plugin problem is fixed.
- Asset-permission errors in the game are independent of these renderer changes.

All temporary diagnostic wrappers in the native Flux module were removed; its
original 99,581-character source was restored. Temporary test shows and helpers
existed only in Play mode. No native Flux source is included in this repository.

## Research used

- [Roblox remote events](https://create.roblox.com/docs/scripting/events/remote):
  client/server dispatch boundaries and replication limitations.
- [Roblox TweenBase](https://create.roblox.com/docs/reference/engine/classes/TweenBase):
  competing tweens on the same property cancel one another.
- [Roblox Motor](https://create.roblox.com/docs/reference/engine/classes/Motor):
  native motor angles are measured in radians.

Flux-specific behavior was verified in the installed kit; public Roblox docs do
not establish the private Flux command schema.
