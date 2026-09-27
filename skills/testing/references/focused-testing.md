# Focused testing

Run cheap test suites broadly. Keep expensive test suites focused on affected seams.

## Selection

Choose scope based on test cost and execution overhead.

- unit tests: run the whole test project
- architecture tests: run the whole test project
- integration tests: affected class or classes
- E2E tests: only when explicitly requested, required by repository policy, or narrower tests cannot validate behavior across deployable boundaries

Use narrower unit-test filtering during tight red/green loops. Repository policy may narrow these scopes, for example leaving whole-project runs to CI.

If integration tests can prove the behavior, skip E2E.

Expand expensive test scopes only when dependencies, failures, or repository policy identify another affected seam.

## Failures

Classify failures before broadening:

- implementation bug
- missed affected dependency
- stale test
- environment or infrastructure failure
- unrelated existing breakage

Broaden expensive testing only when the failure reveals another affected seam.

## Stop

Testing is complete when changed behavior is validated or has a documented gap, required tests and build/static checks pass, and no failure reveals another affected seam.

Repository-wide expensive regression coverage belongs to CI unless repository policy says otherwise.
