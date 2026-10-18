fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build_number

```sh
[bundle exec] fastlane ios build_number
```

Print the next free build number for the current marketing version

### ios release

```sh
[bundle exec] fastlane ios release
```

Archive and upload to App Store Connect. Does NOT submit for review.

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload App Store text only — no binary, no screenshots, no submission

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Upload framed screenshots only — no binary, no text, no submission

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
