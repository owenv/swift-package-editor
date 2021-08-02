# swift-package-editor

Mechanical editing support for `Package.swift` manifests. Implements Swift Evolution proposal [SE-301](https://github.com/apple/swift-evolution/blob/main/proposals/0301-package-editing-commands.md)

## Usage

- Adding dependencies: `swift-package-editor add-dependency https://github.com/apple/swift-nio.git --from 2.0.0`
- Adding targets: `swift-package-editor add-target Foo --type executable --dependencies Bar NIO`
- Adding products: `swift-package-editor add-product MyLibrary --dependencies Foo`

See `swift-package-editor --help` for more information.

## Building

Currently, `swift-package-editor` can only be built with the SwiftPM CLI. Building the package with Xcode will succeed, but fail at runtime due to linker issues.

Because `swift-package-editor` depends on `swift-syntax` to edit `Package.swift` files, it must also be built using a toolchain which closely matches the resolved version of that package. Because `swift-syntax` is integrated using a branch dependency on `main`, usually this is the most recent Swift nightly snapshot. If `SWIFTCI_USE_LOCAL_DEPS` is set, a checkout of `swift-syntax` next to `swift-package-editor` will be used instead. This is intended for use in a build-script build of the Swift toolchain.

## Installing

Run `./Utilities/build-script-helper.py install -h` for details.
