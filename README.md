# BITSBlink — Reed-Solomon Error Correction over GF(2⁸)

A Dart implementation of **Reed-Solomon error-correcting codes** built on top of **Galois Field GF(2⁸)** arithmetic. Designed for reliable data transmission in noisy channels (e.g. optical/flashlight-based underwater communication using 4-PPM modulation).

---

## Project Structure

```
lib/
├── galois_field.dart    # GF(2⁸) finite field arithmetic
└── reed_solomon.dart    # Reed-Solomon encoder & decoder

tests/
├── test.dart            # End-to-end 4-PPM modulation + RS demo
└── test_galois.dart     # Unit tests for GF arithmetic & RS round-trip
```

---

## File Descriptions

### `lib/galois_field.dart`

Core arithmetic for the **Galois Field GF(2⁸)** with primitive polynomial **0x11D** (x⁸ + x⁴ + x³ + x² + 1).

- **`initTables()`** — Precomputes logarithm (`GF_LOG`) and anti-log/exponentiation (`GF_EXP`) lookup tables using the generator element α. Every non-zero field element is expressed as a power of α, enabling O(1) multiplication and division via log-table lookups.
- **`gfMultiply(x, y)`** — Multiplies two field elements: `α^(log(x) + log(y))`.
- **`gfDivide(x, y)`** — Divides via `α^(log(x) - log(y))`, using the cyclic property of the field.
- **`gfInverse(y)`** — Computes the multiplicative inverse: `1 / y`.
- **Polynomial operations** — `Add` (XOR), `Multiply`, `Scale`, `Divide` (extended synthetic division), and `Eval` (Horner's method) over GF(2⁸) coefficient polynomials.

### `lib/reed_solomon.dart`

Full **Reed-Solomon encoder and decoder** using the Galois Field primitives.

- **`rsEncodeMessage(message, nsym)`** — Appends `nsym` error-correction (ECC) symbols to the message using polynomial division by the generator polynomial g(x) = ∏(x − αⁱ).
- **`rsCorrectMessage(message, nsym)`** — Detects and corrects up to `nsym/2` symbol errors:
  1. **Syndrome calculation** — Evaluates the received polynomial at each root of g(x). Non-zero syndromes indicate errors.
  2. **Berlekamp-Massey algorithm** — Finds the error-locator polynomial Λ(x) whose roots identify error positions.
  3. **Chien search** — Brute-force evaluation to find the roots of Λ(x), yielding error locations.
  4. **Forney algorithm** — Computes error magnitudes from the error-evaluator polynomial Ω(x) and the formal derivative of Λ(x).

### `tests/test.dart`

An end-to-end demo simulating an underwater optical link:

1. Encodes the string `"f1end_BITS"` with 8 RS symbols (can correct up to 4 byte errors).
2. Modulates the encoded bytes into a **4-PPM** (Pulse-Position Modulation) boolean signal.
3. Simulates a channel attack (32 consecutive slots forced to darkness ≈ 2 destroyed bytes).
4. Demodulates and applies RS correction to recover the original message.

### `tests/test_galois.dart`

Targeted unit tests:

- Validates `GF_LOG` / `GF_EXP` table sizes (256 / 512).
- Verifies `x · x⁻¹ = 1` for every non-zero element in GF(2⁸).
- RS encode→decode round-trip on a clean message.
- RS correction of a deliberately corrupted message (2 flipped bytes with `nsym=10`).

---

## The Mathematics — A Brief Overview

### Galois Fields (Finite Fields)

A **Galois Field GF(2ⁿ)** is a finite set of 2ⁿ elements where the four operations (addition, subtraction, multiplication, division) are all defined and closed. For GF(2⁸):

- **Elements** are the integers 0–255, each representing an 8-bit binary polynomial (e.g. `0b10011101` → x⁷ + x⁴ + x³ + x² + 1).
- **Addition/Subtraction** is bitwise XOR — no carries, and every element is its own additive inverse.
- **Multiplication** is polynomial multiplication modulo an **irreducible (primitive) polynomial** p(x) = x⁸ + x⁴ + x³ + x² + 1 (`0x11D`). This keeps every product within the 0–255 range.
- A **generator element α** (typically α = 2) generates all 255 non-zero elements as successive powers: α⁰, α¹, …, α²⁵⁴. This cyclic structure lets us replace multiplication with addition of discrete logarithms, using precomputed `EXP` and `LOG` tables.

### Reed-Solomon Codes

Reed-Solomon is a **block error-correcting code** that operates on symbols (bytes) rather than individual bits, making it exceptionally effective against burst errors.

Given a message of *k* symbols and *t* = `nsym/2` desired error-correction capability:

1. **Encoding**: Construct a generator polynomial g(x) = (x − α⁰)(x − α¹)…(x − α^(nsym−1)), then compute the remainder of the message polynomial divided by g(x). This remainder forms the `nsym` parity symbols appended to the message.

2. **Decoding** (error correction):
   - **Syndromes** s_i = R(αⁱ) — if all zero, no errors exist.
   - **Berlekamp-Massey** iteratively builds the shortest LFSR (error-locator polynomial Λ) consistent with the syndrome sequence.
   - **Chien search** exhaustively evaluates Λ at every field element to find roots → error positions.
   - **Forney algorithm** uses Ω(x) = S(x)·Λ(x) mod x^nsym and the formal derivative Λ'(x) to compute each error's magnitude as eⱼ = −(Xⱼ · Ω(Xⱼ⁻¹)) / Λ'(Xⱼ⁻¹), where Xⱼ are the error locators.

The code can correct up to **t = nsym/2 errors**, or **nsym erasures** (errors at known positions), or any combination satisfying `2·errors + erasures ≤ nsym`.

---

## Running

```bash
# Run the end-to-end demo
dart run tests/test.dart

# Run the unit tests
dart run tests/test_galois.dart
```
