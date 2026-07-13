# Today Persistence Manual Test

## Purpose

Verify that Today data survives a full application restart and that nullable
numbers remain distinct from explicitly entered zero values.

## Steps

1. Run the Windows application with `flutter run -d windows`.
2. Enter all three priorities and mark at least one as completed.
3. Select Mood, Energy, and physical state values between 1 and 5.
4. Enter research, learning, sleep, and exercise durations with the separate
   hour and minute fields, then enter a daily note.
5. Select **保存** and confirm that **今日记录已保存** appears.
6. Close the application completely.
7. Start the application again and confirm that every value is restored.
8. Clear both research duration fields and enter `0` hours plus `0` minutes
   for learning.
9. Save, close, and start the application again.
10. Confirm that research minutes is empty while learning minutes displays
    `0`.
11. Enter `-1` in an hour or minute field and select **保存**.
12. Confirm that validation is shown and no save-success message appears.

## Expected Result

- Today and Health summary values survive each restart.
- Empty numeric inputs remain `NULL`; an explicit `0` remains zero.
- Invalid or negative integer values do not trigger a save.
- Minute-part values of `60` or greater do not trigger a save.
- Saving shows an in-button progress state without replacing the form.
- A failed save keeps all current form input available for retry.
