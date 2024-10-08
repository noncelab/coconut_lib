# Contributing

Thank you for your interest and contribution to Coconut Library. All contributors are required to adhere to the guidelines below.

## Commits

All commits should have one of the following prefixes: REL, FIX, ADD, REF, TST, OPS, DOC. For example `"ADD: new feature"`.
Adding new feature is ADD, fixing a bug is FIX, something related to infrastructure is OPS etc. REL is for releases,  REF is for
refactoring, DOC is for changing documentation (like this file).

Commits should be atomic: one commit - one feature, one commit - one bugfix etc.

## Code Review

All submissions, including those from project members, require review. This is done using GitHub pull requests.
For more information about using pull requests, see the [GitHub Help](https://help.github.com/articles/about-pull-requests/).

## Coding Style

The Dart source code in this repository follows the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).
You should familiarize yourself with the guidelines.

## Pubspec

The first time you make a change to a package after publishing, the package's pubspec version must be increased. Additional changes may also require a pubspec version update.
See the [Package Maintenance Wiki](https://github.com/dart-lang/sdk/wiki/External-Package-Maintenance#making-a-change) for a description of the process.

## Change History

Most changes should add a new entry to the CHANGELOG.md file.
A good rule of thumb is that if the change is intended for users, there should be a changelog entry.
This includes documentation changes, such as changes to the README.md file or changes to the dartdoc documentation.

The pubspec version and the changelog version should always match.

## Test

Changes to this repository require testing, but the following PRs are exempt:

- Modify comments (including documentation)
- Modify code in the `.github` directory
- Modify `.md` files
- If generated by an automated bot
- If you have explicit permission from a repository contributor

Repository contributors may indicate that a PR should include tests, despite the general exemptions above.


## Code of Conduct

- Please refer to the [Code of Conduct](CODE_OF_CONDUCT.md) document.
