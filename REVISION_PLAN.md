# Revision plan

Implement these issues in order on main, with one commit per issue.
Each commit starts from the preceding tested commit. Do not develop these changes on parallel branches.

1. Shirt colors (issue 2)
   - Use a shared jersey palette and a reusable shirt view for live play, event entry, and records.
   - Keep the native dropdown with tinted images, and keep black shirts visible on dark screens.
   - Verify the simulator screenshots and existing goal-entry flow.
   - Limit changes to shirt rendering and its screenshot coverage.
2. Game ending and game library (issue 1)
   - Save game date, time, and a manually entered location; preserve older records.
   - Return to Previous games after successfully saving the final half.
   - Provide New game, resume, and reliable navigation from completed records.
   - Reuse the shirt view from issue 2 without changing its implementation.
   - Test a full game, return navigation, another game, relaunch, and record compatibility.
3. Vibration (issue 3)
   - Keep the existing alert schedule and use maximum-intensity repeated pulses.
   - Make the half-end pattern longer and distinct from the advance warnings.
   - Keep settings test buzzes connected to the same production patterns.
   - Limit code changes to haptic playback; leave navigation, storage, and shirt rendering unchanged.
   - Compile and check the patterns; physical noticeability remains a device trial.

Shared UI and test files are edited sequentially in separate sections, so the commits do not compete for the same changes.
Run the relevant checks before each commit. Review staged files and commit metadata for personal identifiers before publishing.
