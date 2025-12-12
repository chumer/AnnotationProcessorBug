# AnnotationProcessorBug

This project reproduces an annotation processing issue where the compiler reports the enclosing element of a binary type as a package instead of the containing class, causing the processor to fail with `Expected a class enclosing element bug got kind PACKAGE: dependency`.

## Issue description
- Scope: only ECJ 3.44.0 fails; javac and ECJ 3.39.0–3.43.0 behave correctly.
- Setup: an annotation processor inspects the return type of an annotated method. The return type is a binary type (`dependency.OtherClass`) whose own method returns a nested binary class (`dependency.BinaryDependency.InnerClass`).
- Expected: `getEnclosingElement()` on the nested binary class returns the enclosing class `dependency.BinaryDependency`.
- Actual (ECJ 3.44.0): `getEnclosingElement()` returns a package element (`dependency`), so the processor emits `Expected a class enclosing element bug got kind PACKAGE: dependency` and ECJ exits with an error.
- The regression is reproducible by running the script below; see `target/ecj-3.44.0.log` for the failing trace.

## Prerequisites
- JDK 21 on `PATH` (`java`/`javac`).
- Maven and `curl`.
- Network access to download ECJ jars (cached in `.ecj/` after the first run).

## How to run
1. From the repo root, execute `./build-with-local-ecj.sh`.
   - The script builds the processor and dependency with Maven, then compiles the reproducer with `javac` and each ECJ version.
   - Logs live in `target/javac.log` and `target/ecj-<version>.log`; generated classes/sources sit under `target/`.
2. Optional knobs:
   - `ECJ_VERSIONS="3.44.0 3.43.0 3.42.0"` to choose which ECJ releases to test.
   - `JAVA_RELEASE=21` (default) to change the `--release` level passed to the compilers.

The summary the script prints shows `status` (compiler exit code), `bug` (whether the processor reported the enclosing-element error), and the log path. When the bug triggers the compiler exits with an error, so `bug=yes` implies `status=fail`.
