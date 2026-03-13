# Vendored c-testsuite subset

This directory contains the curated `single-exec` subset used by c4c.

Layout:
- `src/`: vendored test cases and sidecar files (`.expected`, `.tags`, `.otags`)
- `allowlist.txt`: manifest of the vendored cases registered by CMake
- `RunCase.cmake`: per-case runner
- `LICENSES/`: upstream license material relevant to the framework and test cases

The source of truth for what is included is this directory, not the original
upstream repository layout.
