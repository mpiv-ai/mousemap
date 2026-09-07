# MouseMap

## Working agreement

Finish the authorized task through verification and integration. Preserve existing edits and unresolved requests across interruptions. Make routine implementation decisions locally; ask only when a missing decision materially changes the outcome. Existing authorization persists across turns.

Use tools available in the current session. Skills provide task guidance; they do not impose unrelated workflows or authorize external actions. Keep runtime model selection in the harness. Commits, pushes, publishing, messages, credential changes, and destructive operations need authorization covering the action. Do not add agent or model attribution.

Run checks appropriate to the change and required repository gates. Broaden or repeat checks for new changes, failures, or unresolved concerns. Report the result, verification, and actual limitations concisely.

## Repository context and verification

`mousemap.swift` owns HID report handling and CGEvent shortcuts. `mousemap.example.json`, `Info.plist`, and the LaunchAgent plist document configuration and packaging. Preserve normal mouse behavior and the distinction between raw keyboard-class HID reports and ordinary extra buttons.

`make build` compiles locally with Swift and Apple frameworks. Validate changed JSON with `python3 -m json.tool mousemap.example.json` and changed plists with `plutil -lint`. There is no automated test target. Report hardware behavior as unverified until deliberately exercised. `make install`, `make uninstall`, `make reload`, and `make learn` affect live input, permissions, or installed state; run them only when that operation is authorized.
