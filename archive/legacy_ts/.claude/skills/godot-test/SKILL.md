---
name: godot-test
description: Run the Tactical Summoners Godot test suites and screenshots and report real PASS/FAIL. Use after any change to scripts/, scenes/ or tests/, or when the user asks to test, verify, check or screenshot the game.
---
# Godot tests for Tactical Summoners

Never report PASS without real output. Pick the first route that works:

1. **Local Godot available** (`command -v godot` or `$GODOT`):
   `GODOT=<path> bash tools/run_tests.sh` → read `tools/last_test_run.txt`.
2. **No local Godot (cloud session)** → GitHub Actions (`.github/workflows/godot-ci.yml`):
   - Commit and push to the working branch (only with the user's permission for pushes).
   - Find the run: GitHub MCP `actions_list` method `list_workflow_runs` filtered by branch; then `list_workflow_jobs`.
   - When finished, read the `tests` job log with `get_job_logs` (`return_content: true`, `tail_lines: 120`) and copy the PASS/FAIL block.
   - Screenshots: artifact `screenshots` of the same run (`list_workflow_run_artifacts`). Tell the user they can open it from the run page on GitHub.
3. **Owner's Windows PC:** `powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1`.

Report: one line per suite, the exact failing checks, the run URL, and what was NOT verified (visuals are only checked through screenshots).
Then update only the evidence-backed rows of `docs/IMPLEMENTATION_STATUS.md` and the version entry in `docs/VERSIONS.md`.

Adding a suite: create `tests/<name>.gd` (+ `.tscn` for scene tests), print `  PASS  ` / `  FAIL  ` lines and `ALL PASSED`, quit with exit code = failures, and register it in BOTH `tools/run_tests.sh` and `tools/Run-Tests.ps1`.
