---
name: clojure-paren-repair
description: Repair unbalanced parentheses, brackets, and braces in Clojure, ClojureScript, and EDN files. Use when you encounter delimiter mismatch syntax errors after editing .clj, .cljs, .cljc, or .edn files.
---

# Clojure Parenthesis Repair

The command `clj-paren-repair` is installed on your path.

## Usage

```bash
clj-paren-repair <files>
clj-paren-repair path/to/file1.clj path/to/file2.clj
```

## When to Use

Run this tool when you encounter unbalanced delimiters (parentheses, brackets, braces) in Clojure, ClojureScript, or EDN files.

**IMPORTANT:** Do NOT try to manually repair parenthesis errors. If you encounter a file with unbalanced parentheses or delimiters, run `clj-paren-repair` on that file instead of attempting to fix the delimiters yourself.

## Tool Behavior

- **Delimiter Repair:** Identifies and fixes common delimiter errors such as unbalanced parentheses
- **Code Formatting:** Automatically formats files with `cljfmt` when processing, regardless of whether a delimiter error was fixed

## If the Tool Fails

If `clj-paren-repair` doesn't fix the problem, report to the user that they need to fix the delimiter error manually. Do not continue attempting repairs.
