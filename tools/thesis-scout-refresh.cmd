@echo off
REM ============================================================================
REM  Neuro Digital Twin - scheduled literature refresh
REM
REM  Invoked by the Windows scheduled task "Neuro Twin Thesis Scout", every
REM  3 days. Runs headless Claude Code, which delegates to the thesis-scout
REM  agent in refresh mode.
REM
REM  Why Task Scheduler rather than CronCreate or a cloud routine:
REM    - CronCreate is session-only and recurring jobs expire after 7 days.
REM    - Cloud routines cannot reach the local Obsidian vault.
REM  See memory: tooling-thesis-scout-schedule
REM
REM  Manual run:  schtasks /Run /TN "Neuro Twin Thesis Scout"
REM  Log:         tools\thesis-scout-refresh.log
REM ============================================================================

setlocal
set "PROJ=C:\Users\HUAWEI\Documents\Final Year Project 2026\FYP"
set "CLAUDE=C:\Users\HUAWEI\AppData\Roaming\npm\claude.cmd"
set "LOG=%PROJ%\tools\thesis-scout-refresh.log"

cd /d "%PROJ%" || (echo [%DATE% %TIME%] FATAL: cannot cd to project >> "%LOG%" & exit /b 1)

echo. >> "%LOG%"
echo ==================== [%DATE% %TIME%] run starting >> "%LOG%"

call "%CLAUDE%" -p "Use the thesis-scout agent to run a scheduled refresh pass. Re-run the standing queries date-filtered to since the last entry in Scout Log.md. Write only genuinely new papers as notes in the vault Literature folder, never overwriting an existing note body, and never touching the Synthesis folder. Append a dated entry to Scout Log.md recording the queries run, new notes created, count skipped as already known, and any contradicting evidence found - log the run even if nothing new was found. If a finding changes a design decision, say so clearly in your summary." >> "%LOG%" 2>&1

echo ==================== [%DATE% %TIME%] run finished, exit=%ERRORLEVEL% >> "%LOG%"
endlocal
