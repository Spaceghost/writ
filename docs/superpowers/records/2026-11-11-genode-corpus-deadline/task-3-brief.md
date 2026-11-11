# Task 3: integrate the verified change

Use the user's existing explicit instruction to push to master. Fetch current
master, preserve any intervening work, and verify that the final native runtime
and generated Bend inputs match the successful candidate or rerun affected
checks if integration changes them. Refresh and verify the complete tracked
source manifest, excluding itself. Push normally, never force, and confirm the
remote revision. Record newly triggered CI as pending until its actual result
is available. Leave the shared Windows checkout and other lanes intact.
