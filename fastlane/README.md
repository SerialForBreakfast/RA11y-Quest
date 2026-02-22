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

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture UI screenshots across multiple simulators.

Simulator selection is dynamic — xcrun simctl is queried at runtime and
each preferred device is resolved to a UDID. Hardcoded names are used only
as preferences, never as bare destination specifiers.

Uses xcodebuild test + xcresulttool (Xcode 16+ compatible). Replaces
fastlane `snapshot`, which cannot parse the zstd-compressed xcresult
attachment format introduced in Xcode 16.

Screenshots land in fastlane/screenshots/en-US/<label>/

Fails loudly (UI.user_error!) if zero devices succeed.


----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
