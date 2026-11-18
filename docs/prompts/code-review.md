# Code review prompt

Codex gets this prompt to review one ticket's PR, after the Proof is shown on the running app and before the merge.

```
Review this ticket's PR independently. Edit nothing. Read applicable project
rules, Now/Wanted/Not in this/Proof, the base-to-head diff, affected callers,
running-app evidence and local check results. Identify the reviewed head.

Prioritize ticket intent, practical correctness and regressions, then
simplicity. The new behaviour must work as the ticket intends, and existing
behaviour that this change touches must still work. Trace relevant permission,
cancellation, capture and privacy paths. Check for unnecessary tests, unused
options, dead code, duplicated policy/state and speculative abstractions.

Report only a demonstrated supported failure or concrete unnecessary burden
today, with a correction worth its complexity. Accept reproduction or decisive
code evidence. Exclude hypothetical scale, cosmetic preferences, unrelated
cleanup and automatic test demands. A demonstrated risk of leaking private
content, keys or recordings is reported even when it is unlikely.

Give at most five distinct findings, ordered by consequence. Each needs
priority, file/line, evidence/trigger, consequence and smallest correction.
Disclose overflow; withhold readiness.

Separately state verification gaps. Missing proof means "Not ready:
verification incomplete." Otherwise, if clean: "No actionable findings,"
followed by ticket/simplicity assessment and verification limits.
```

After fixes, the next review checks only the fixes and the paths they touch, not a fresh full review.
