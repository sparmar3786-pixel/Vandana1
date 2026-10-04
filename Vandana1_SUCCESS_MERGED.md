# Vandana1 — Successful Build Merge Manifest

Created: 2026-10-04
Repository: sparmar3786-pixel/Vandana1

## Purpose
Clean merge reference containing only verified successful GitHub Actions build states. Failed workflow runs are excluded.

## Primary verified UI/build baseline
- Build Parmar Trading APK: run #356
- Workflow run ID: 37067005033
- Commit: 835d4f7afa011c08cf46fb5dfbf9b3b35ba1c347
- Commit message: feat: replace dashboard with auto-refresh dashboard
- Result: success
- Attempt: 2
- This is the Vandana1 Build 356 UI master baseline.

## Matching successful native baseline
- Build Native Android APK: run #31
- Workflow run ID: 37067005010
- Commit: 835d4f7afa011c08cf46fb5dfbf9b3b35ba1c347
- Result: success

## Other verified successful runs
Native Android:
- #43 — 37109353233 — 8f67a23f28f17225f88f64e1592c6a876e2ae0eb
- #42 — 37109328176 — 82d69eae092c9ac5c4fa03b33a2e6699fbce5f10
- #41 — 37109262170 — 404d739b540b60d0746d50bfdebdf6cee4b4c192
- #40 — 37109250770 — d18d79f10990678cde787d391093adae349af919
- #39 — 37109248550 — cde420ace384d6be5d5ce3d623b1cb969511ae7e
- #38 — 37108903103 — b142b5d88219cbf9ab4e941bb321cca2253348f0
- #37 — 37108869003 — 0e6d9b049ebb52c6cff0fbd0faf78a8448c4b2a0
- #36 — 37108831845 — ccd0d192c27897b69f82c6f8556ad7ca49695e2d
- #35 — 37107007904 — 2cf557341961f81406f1c96a1c108947559a320c

Parmar Trading APK:
- #421 — 37105443346 — 57748dfd2273e7e26c02b37e7f50da8d7013c3a6
- #419 — 37104892877 — 950f391df0522a3686ca506acd568d1e028a7438
- #405 — 37099388286 — de3fc5b2be506f27b42b4bf18ebb6f5ddade4f9d
- #404 — 37099380168 — 0a5eda193c3a62a8d7a7f784f82cc6a5a1edf2b6
- #403 — 37098503855 — 99fdd482a2635ba82f7f3dcc679323ea02f68769
- #402 — 37096642785 — 581d44cb6d76fb40c03a50493d763de105540ee3
- #388 — 37094582090 — d09ea0d94327bf94476cb31327a2387b39d293cc
- #384 — 37094390951 — 4296fea1346f77c61b0f92a3368bba3f3

## Merge rule
Use Build 356 commit 835d4f7afa011c08cf46fb5dfbf9b3b35ba1c347 as the primary UI/reference state. Do not copy failed-build-only changes into the clean merge. New functionality must be validated by a successful workflow before being promoted.

## Important
This file is a verified build manifest/reference, not a binary APK and not a rewrite of Git history. GitHub Actions history remains unchanged.
