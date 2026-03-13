Upstream repository: https://github.com/c-testsuite/c-testsuite

Upstream source path: `tests/single-exec/`

Vendored subset policy:
- Only cases listed in `allowlist.txt` are copied into `src/`
- Sidecar files required for execution or license tracing are kept next to each case

License notes:
- `LICENSES/framework.LICENSE` covers the upstream test framework repository
- `LICENSES/testcases.LICENSE` notes that individual test case licensing is
  discoverable through `.otags` files shipped in `src/`
