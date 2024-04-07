# Release

[![exist-db CI](https://github.com/HistoryAtState/release/actions/workflows/build.yml/badge.svg)](https://github.com/HistoryAtState/release/actions/workflows/build.yml)

A collection of utilities for preparing releases:

- Quarterly Release Helper: generates draft press release and tweets for “quarterly releases” of the _FRUS_ Digital archive
- Ebook Batch Helper: generates epubs and mobi-bound epubs of _FRUS_ volumes from TEI XML

## Dependencies

- Assumes [HistoryAtState/hsg-project](https://github.com/HistoryAtState/hsg-project) is installed

## Build

1. Single `xar` file: The `collection.xconf` will only contain the index, not any triggers!

    ```shell
    ant
    ```

    1. Since Releases have been automated when building locally you might want to supply your own version number (e.g. `X.X.X`) like this:

    ```shell
    ant -Dapp.version=X.X.X
    ```

## Deploy

Releases for this package are automated. Any commit to the `master` branch will trigger the release automation.

All commit message must conform to [Conventional Commit Messages](https://www.conventionalcommits.org/en/v1.0.0/) to determine semantic versioning of releases, please adhere to these conventions, like so:

| Commit message  | Release type |
|-----------------|--------------|
| `fix(pencil): stop graphite breaking when too much pressure applied` | Patch Release |
| `feat(pencil): add 'graphiteWidth' option` | ~~Minor~~ Feature Release |
| `perf(pencil): remove graphiteWidth option`<br/><br/>`BREAKING CHANGE: The graphiteWidth option has been removed.`<br/>`The default graphite width of 10mm is always used for performance reasons.` | ~~Major~~ Breaking Release |

When opening PRs commit messages are checked using commitlint.