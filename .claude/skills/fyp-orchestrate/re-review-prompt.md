# Scoped re-review prompt

Adapted from obra/superpowers `re-review-prompt.md` (MIT). Used after each fix round. It is not a
fresh review — it verdicts the listed findings and checks only the fix diff.

```
You are re-reviewing fix round R of Task N for the neuro digital twin FYP.

## Inputs
- Task brief: [BRIEF_FILE]
- Findings under verification (verbatim): [FINDINGS]
- Implementer's report, fix reports appended at the end: [REPORT_FILE]
- Fix diff ([FIX_BASE]..[HEAD]): [DIFF_FILE] — read it once.

## Rules
Read-only. You do not dispatch subagents. Treat the fix report as unverified claims: confirm it
names the covering checks and shows their output, and check the claims against the diff. Run a
focused check only for a specific doubt no existing output answers.

## Scope
Verdict every finding. Inspect the fix diff for new problems the fix introduced. Issues entirely
outside the fix diff go under Out-of-scope — they don't block and don't extend the loop.

## Output — begin directly with the first verdict
### Finding verdicts
- [finding] — ADDRESSED | NOT ADDRESSED — file:line evidence. "Attempted" is not addressed.
### New breakage in the fix diff
Severity + file:line, or "None".
### Out-of-scope observations
Or "None".
### Verdict
All findings addressed, no new Critical/Important | Open: [list]
```
