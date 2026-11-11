# Task 4 report: live site and reviewable source

The website is published at https://spacegho.st/writ/. `/writ` redirects to the
canonical trailing-slash URL. The new writ-site Worker handles only the two
reviewed routes. The previous 67 routes are unchanged. Returned deployment
identity, bundle hash and route IDs are in verification/project-site-20261111/
deployment.json. Its source is bace016; later changes in this lane record
publication only and do not change the site package.

Live curl checks passed for the page, all three assets, redirect, HEAD, 404
and 405 behavior. Asset bytes match the packaged SHA-256 values. The existing
zone's JavaScript detection inserts a challenge script into HTML; the application
HTML matches after isolating that specific provider insertion. A first Python
urllib fetch returned 403; curl and Chromium returned 200. No zone security
settings were changed. Live Chromium also passed both denial illustrations
and the 390px layout. Local browser checks are recorded separately.

The first hosted Writ core checks run succeeded on bace016:
https://github.com/Spaceghost/writ/actions/runs/43075114424
This exercises the new workflow on a branch push, not native/Nix qualification.

Branch lane/project-site is pushed. PR creation is blocked by existing GitHub
permissions: the connector returned HTTP 403 Resource not accessible by
integration, and gh (authenticated as Spaceghost) returned a CreatePullRequest
permission error. No PR was created and master was not changed. Reviewable diff:
https://github.com/Spaceghost/writ/compare/master...lane%2Fproject-site
No maintainer was contacted directly.
