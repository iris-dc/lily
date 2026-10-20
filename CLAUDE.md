# Claude Code notes for lily

@AGENTS.md

The guide above and `docs/notes/` hold everything about the project; this file is only what differs for Claude Code.

- **Logs to grep.** With `xcodebuild` or `ci.sh` output redirected to a file: `error:`, `/lily/.*: warning:`,
  `Test Case .* (passed|failed)`, `Test run with`, `SUCCEEDED|FAILED`.
- **Subagents and the simulator.** Agents that build, test or capture in parallel each take their own simulator device
  by UDID; never two `xcodebuild test` sessions on one device. A review agent given a whole multi-slice diff ran out
  of input twice: split reviews by slice, and keep screenshot judging in a separate agent from code review.
- **Screenshots never enter the parent session.** A full-size PNG read with `Read` costs about 1,600 tokens and
  670 KB of transcript; a session that reads a hundred dies of `API Error: 400 Input is too long`, and `/compact`
  then fails the same way. A subagent judges screenshots and reports text; a parent that must look reads a
  downscaled copy (`sips -Z 800 shot.png --out /tmp/small.png`). A `PreToolUse` hook in `~/.claude/settings.json`
  refuses images over 1000 px.
- **The user's project files outside the repository.** Plans and wire contracts shared with Laurel and rose:
  `~/.claude/projects/-Users-makshr-lily/groups-plan/`; review reports: `~/.claude/projects/-Users-makshr-lily/reviews/`.
