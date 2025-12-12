# ECJ 3.44.0: binary nested class reports package as enclosing element

## Summary
- Annotation processor inspects a nested binary class and expects `getEnclosingElement()` to be the enclosing class.
- ECJ 3.44.0 returns a package element instead, causing the processor to emit an error and compilation to fail.
- javac and ECJ 3.39.0–3.43.0 behave correctly; regression is isolated to 3.44.0.

## Reproducer
1) Clone this repo and ensure JDK 21, Maven, and `curl` are on `PATH`.
2) Run:
   ```bash
   ./build-with-local-ecj.sh
   ```
   - Downloads ECJ jars to `.ecj/` (Maven Central) and builds the artifacts locally.
   - Compiles the reproducer with javac and ECJ 3.39.0–3.44.0.

## Expected result
- For the nested binary type `dependency.BinaryDependency.InnerClass`, `Elements#getEnclosingElement()` should return the enclosing class `dependency.BinaryDependency`.

## Actual result (ECJ 3.44.0 only)
- `getEnclosingElement()` returns a package element (`dependency`), so the processor emits:
  ```
  Expected a class enclosing element bug got kind PACKAGE: dependency
  ```
- See `target/ecj-3.44.0.log` for the failing trace; earlier ECJ versions and javac succeed (logs under `target/`).

## Notes
- The return type being examined comes from a binary dependency (`dependency.OtherClass`) whose method returns the nested class.
- The processor short-circuits successfully when the enclosing element is a class (all versions except ECJ 3.44.0).
