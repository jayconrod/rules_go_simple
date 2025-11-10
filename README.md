`rules_go_simple` is a simple set of Bazel rules for building Go code.  It
is intended to be a simple, clean, minimal example of how to write Bazel
rules for new languages.

The rules are divided into versions (v1, v2, etc.). Each version builds
upon the last and includes all the functionality of the previous
versions. The solutions are fully commented.

The process of writing each version is documented in a [series of blog
posts](https://jayconrod.com/posts/106/writing-bazel-rules--simple-binary-rule).

You can also find a [slide deck for the workshop](writing-bazel-rules.pdf)
based on these rules.

* **[v1](https://github.com/jayconrod/rules_go_simple/tree/v1)**: A minimal
  example of a rule that produces an executable (`go_binary`). Described in
  [Simple binary
  rule](https://jayconrod.com/posts/106/writing-bazel-rules--simple-binary-rule).
* **[v2](https://github.com/jayconrod/rules_go_simple/tree/v2)**: Adds a small
  rule that produces a library (`go_library`). Described in [Library rule,
  depsets,
  providers](https://jayconrod.com/posts/107/writing-bazel-rules--library-rule--depsets--providers).
* **[v3](https://github.com/jayconrod/rules_go_simple/tree/v3)**: Adds a `data`
  attribute. Described in [Data and
  runfiles](https://jayconrod.com/posts/108/writing-bazel-rules--data-and-runfiles).
* **[v4](https://github.com/jayconrod/rules_go_simple/tree/v4)**: Moves most of
  the implementation out of Starlark into a "builder" binary. Described in
  [Moving logic to
  execution](https://jayconrod.com/posts/109/writing-bazel-rules--moving-logic-to-execution).
* **[v5](https://github.com/jayconrod/rules_go_simple/tree/v5)**: Downloads the
  Go distribution and registers a Bazel toolchain. Described in [Repository
  rules](https://jayconrod.com/posts/110/writing-bazel-rules--repository-rules).
* **[v6](https://github.com/jayconrod/rules_go_simple/tree/v6)**: Defines a
  module extension that selects a Go version, instantiates the previous
  repository rule, and registers toolchains to avoid redundant downloads.
  Described in [Module
  extensions](https://jayconrod.com/posts/131/writing-bazel-rules-module-extensions).
