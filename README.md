# Release

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