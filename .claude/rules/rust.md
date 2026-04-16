# Rust Rules

## Format
- Tool: `cargo fmt`
- Config: rustfmt.toml (if exists)

## Lint
- Tool: `cargo clippy -- -D warnings`
- All clippy warnings are errors

## Test
- Command: `cargo test`
- Coverage: `cargo llvm-cov` (if installed)

## Build
- Command: `cargo build --release`

## Project Structure
- src/lib.rs: library entry point
- src/main.rs: binary entry point
- tests/: integration tests
- benches/: benchmarks
