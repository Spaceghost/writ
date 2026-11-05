### Task 2: Appliance rules applied to the library image (3.2)

Write `verification/unikernel-appliance-rules.md`: one row per UA-001 to UA-010 (quote each requirement's title from the appliance change's spec), with the evidence file and section that meets it for the library image, or an explicit gap in the requirement's own words. Run the rebuild drill the appliance change describes (a clean rebuild of one image from the pinned sources, with elapsed wall time and the resulting hash against the recorded one; note that Unikraft clean builds embed the build time so the hash differs, and say what is compared instead). Write the trusted-base statement (the libraries in the image from `unikernel-pins.txt` and the inventory, including the experimental signal library). Check 3.2 citing the file.

Acceptance: ten rows, each with evidence or a quoted gap; the drill's elapsed time and hash comparison recorded; the trusted-base statement names every library.

