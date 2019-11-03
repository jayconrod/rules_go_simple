`rules_go_simple` is a simple set of Bazel rules for building Go code.  It
is intended to be a simple, clean, minimal example of how to write Bazel
rules for new languages.

The rules are divided into versions (v1, v2, etc.). Each version builds
upon the last and includes all the functionality of the previous
versions. The rules are fully commented, and the process of creating each
version is documented in a series of blog posts at
[jayconrod.com](https://jayconrod.com/).

* **v1**: A minimal example of a rule that produces an executable
  (`go_binary`). Described in
  [Simple binary rule](https://jayconrod.com/posts/106/writing-bazel-rules--simple-binary-rule).
* **v2**: Adds a small rule that produces a library
  (`go_library`). Described in
  [Library rule, depsets, providers](https://jayconrod.com/posts/107/writing-bazel-rules--library-rule--depsets--providers).
* **v3**: Adds a `data` attribute. Described in
  [Data and runfiles](https://jayconrod.com/posts/108/writing-bazel-rules--data-and-runfiles).
* **v4**: Moves most of the implementation out of Starlark into a
  "builder" binary. Described in
  [Moving logic to execution](https://jayconrod.com/posts/109/writing-bazel-rules--moving-logic-to-execution).
