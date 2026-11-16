# nbkit: notes for Claude Code

The main note (rules, how to run, pitfalls, versions, roadmap, pending items) is imported here, so it is always loaded:

@.claude/notes/nbkit.md

Read the other notes when the task needs them (not imported, to save context):
- `.claude/notes/nbkit-jsf.md`: any work on the JSF check (src/nbkit-jsf, analyze, NetBeans rules, fixtures).
- `.claude/notes/nbkit-v6.md`: architecture decisions for v5/v5.5 and the v6 plan.
- `.claude/notes/nbkit-historico.md`: what was already done and committed.

Essentials:
- Never commit or push. When work is ready, give the ready command `git commit -m "..."` (single quotes inside, no AI attribution).
- Tests fail first, then pass. Run `bash tests/run.sh` (or the part you touched) before saying something is done.
- Every feature: backend logic, CLI tip, GUI tooltip, lang keys in en and pt-BR, tests.
- Use the ponytail skill when writing code (smallest complete change). Not for tests.
- Respect the architecture in `nbkit.md` ("Architecture"): logic in the backend (`lib/`), exposed through `nbkit.sh` and `status --json`; the GUI (`model.py` decides, `app.py` only draws) and the CLI menu only call it.
- No names of his work projects in the code, messages, fixtures or anything committed (this file included). `.claude/notes/` is local only and never committed (it may name them).
- No em dashes in anything written for him.
- Answer him in Brazilian Portuguese, concise.

Keeping the notes current:
- After each thing done, validated, decided, committed or pushed, add a dated line to `.claude/notes/nbkit-historico.md`, and update `nbkit.md` / `nbkit-jsf.md` / `nbkit-v6.md` when a plan, design or pending item changes. Keep them concise and organized: edit lines in place instead of piling up notes.
- These 4 files are synced with his chat assistant's memory: he sends them before going to work and brings the updated versions back. Keep the file names and the frontmatter.
