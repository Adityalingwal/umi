# AGENTS.md

Umi is a voice-first buddy for macOS, written in native Swift and SwiftUI. Mac only.

- The app will grow large: many features will be added over time. Choose a structure that fits that size, even when a feature's first version is small. This is not a reason to build anything a ticket does not ask for.
- The interface is to be best in class. Interface work is done only when the interaction feels finished (timing, animation, loading, empty and error states), not only when it works.

How to build, sign and run the app is in `docs/build-and-run.md` (written in the first ticket).

## Planning

Pick the size of a change first. Three questions decide it: will one small PR leave something runnable; can you say how "done" is checked without guessing; does it touch another task, a permission, private data or something hard to undo.

- Tiny (one line, a typo, a colour): change it on `main` after the local checks pass and Aditya says yes. No branch, no PR.
- Medium (one clear piece of work): one GitHub issue, one agent, one PR. The issue is the brief; there is no separate brief document.
- Large (a feature, several PRs): a grill, then a spec as the parent issue, then thin end-to-end child issues, one PR each. Only child issues go to an agent, never the parent.
- Unknown technology at any size: a throwaway prototype first.

Words: a spec is the parent issue of a large change; a ticket is one small piece of work (a child issue, or the single issue of a medium change).

A ticket has four parts: Now (what happens today), Wanted (what should happen, from the user's side), Not in this, Proof (what the agent will show to prove it works). When an important behaviour is checked on the running app instead of a test, Proof also asks for one adverse case, such as cancel mid-answer, permission denied or network off.

A spec has six parts: Problem, Solution (what the user sees and hears), Cases (user cases not obvious from Solution), Decisions (the parts and the interfaces between them, no file paths), Tests (the few important things that get a test), Not in this. A spec holds only what Aditya said in the grill; anything the agent added on its own is a defect.

A grill asks one question at a time, each with your recommended answer. Find facts yourself (what an API can do, what the code does today); ask Aditya only about choices. For a large or hard-to-undo design choice, when Aditya wants alternatives, a second model gets the same open question on its own and the two answers are compared for him, before the spec is written.

Stop and report instead of guessing when the ticket is unclear, when a decision looks wrong, or after two failed attempts at the same fix. Do not widen the scope.

## Checking your work

- You build, launch and drive the Debug app yourself to check your work, using computer use. A test is written only where one is earned (see Tests); everything else is shown on the running app.
- Only one agent drives the running app at a time; there is one screen. Writing code may run in parallel.
- Every development build is signed with the one stable Apple Development identity, never ad-hoc, so permissions survive rebuilds. The Debug app is `Umi Dev` with a `.dev` bundle ID.
- Build output goes inside your own checkout (`-derivedDataPath` in the worktree), never a shared folder.
- A proof screenshot shows only the app's own window with made-up content, never Aditya's real screen.

## Tests

- A behaviour gets a test only when both answers are yes: would breaking it do serious harm (exposing private content, wasting money, losing work, or breaking the main speak, see, answer flow), and can one small test catch it without a lot of fake setup? Being easy to test earns nothing.
- No new test is better than a bad test.
- Test behaviour, not implementation: a test goes red when something the user can observe breaks, and stays green when only the inside changes.
- When a test would need a lot of fake setup, do not write it; check the same thing on the running app.
- Never write a test before the code on your own. Write a test only when the ticket's or spec's Tests part names it. A bug follows the same two questions: both yes means a test plus the fix; otherwise the fix, shown on the running app.
- "Checking it on the running app is slow" is not a reason to add a test.
- Fix the code, not the test; keep existing tests and checks intact.

## Code

- One file holds one concept. Split by concept, never by size.
- Size numbers are prompts, not limits: a file over 400 lines, a function over 50, or a SwiftUI view `body` over 80. When one is passed, check whether a second concept is hiding. If yes, split it; if no, say in one line in the PR why it stays whole. "It is all one concept" is not an excuse for a 1,000-line file.
- A function has one job.
- No comments by default. A comment is allowed only where the reason for the code cannot be read from the code, and it stays short. No header comments at the top of files.
- Code lives in one folder per feature (`Features/<Feature>/`); tests mirror the feature folders. A feature is a large part of the app the user knows by name, such as voice, screen or pointer. A smaller addition goes into the feature it belongs to. Ask Aditya before creating a new feature folder.
- Tell Aditya at once when code in one feature uses something inside another feature. After every spec, report in one line the number of files, lines and folders, so the layout can be reopened before it hurts.
- Ask Aditya before adding a dependency (a Swift package or any other library).
- Before writing or changing Swift code, read `docs/swift-style.md`.

## Privacy and safety

- Nothing private is published. A capture of the real screen, a recording of real audio, or its transcript never goes into a commit, a PR or an issue.
- Files made while testing (screenshots, recordings, test notes) go in `.proof/<ticket number>/`. Other working files that are not meant to be pushed (findings, review answers, notes) go in `.work/<ticket number>/`. Both are git-ignored. In cleanup, delete only your own ticket's folder, never `.proof/` or `.work/` themselves and never another ticket's folder.
- No committed file holds details of Aditya's Mac: his name, Apple Team ID, signing identity name, or paths under `/Users/`. Use a placeholder. When unsure, ask Aditya before committing.
- Keys live in the git-ignored `.env`. Never read, print or commit a key. The build reads `.env` and writes a generated, git-ignored file the app reads; a new worktree links to the main checkout's `.env` instead of copying it.
- The app may send the real screen and voice to the services it already uses (Claude, Codex, Deepgram). Ask Aditya before sending a capture anywhere else, a new model platform included, and before anything that costs money.
- Never run `tccutil` or change macOS privacy grants; Aditya grants a permission himself when the app first asks.
- Never create, export or delete a certificate, private key or Keychain item. Use the existing Apple Development identity by its name only.
- Launch only the `Umi Dev` build from your own checkout; never an installed copy of `Umi` or another app.
- When Aditya asks whether a tool or the app can reach something private (an SSH key, files, the screen), answer truthfully. Screen recording, Accessibility, automation and terminal access are powerful; never say they "cannot" do something. Say what the access allows, then where safety really lies: the code is his and can be read, and you did not do it, shown by the exact commands you ran.

## Git

- All repository content is English: code, comments, docs, commits, PRs.
- Branch: `<ticket number>-<short-name>`, for example `12-speak-to-text`. Worktree: `../umi-worktrees/<ticket number>-<short-name>`.
- One commit has one purpose and a one-line message.
- Merge with a merge commit, never squash. Never force-push. Any skill that squashes or force-pushes is overridden by this rule.
- Prove the ticket on the running app first; then Codex reviews the code with `docs/prompts/code-review.md`. A spec gets one completeness check from Codex with `docs/prompts/spec-check.md`. A ticket itself gets no model review.
- The PR body says `Closes #<number>`.
- Open your own PR yourself. Merge it yourself once the Proof is shown, Codex's review is answered and the local checks pass. Ask Aditya before merging when the ticket touches a permission, private data, signing, keys or something hard to undo.
- Cleanup is the last step of every ticket, done without asking once the PR merges: delete the branch locally and on GitHub, remove the worktree, delete `.proof/<ticket number>/` and `.work/<ticket number>/`, pull `main`. Touch only your own ticket's branch and worktree.
- One agent works at a time until the first three or four tickets have run the whole loop; then two or three, only on tickets that do not touch the same files.

## Done means

- The local checks pass. The one command that runs them all is not decided yet.
- The ticket's Proof is shown on the running app, adverse case included.
- The report shows the real output and says what was not verified.
- There is no CI; nothing runs on GitHub.
