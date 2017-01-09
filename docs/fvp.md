# OP-TEE on Foundation Models / FVP

# Contents
1. [Introduction](#1-introduction)
2. [Regular build](#2-regular-build)

# 1. Introduction
The instructions here will tell how to run OP-TEE using Foundation Models.

# 2. Regular build
Start out by following the "Get and build the solution" in the [README.md] file,
but before trying to actually run the solution you must first obtain the
[Foundation Models binaries]. That binary should be untar'ed to the root of the
repo forest. I.e., the folder named `Foundation_Platformpkg` must be in the root.
When this pre-condition has been done, then you can simply continue with
```bash
$ make run
```
And the FVP should build the root fs and then start the simulation.

[Foundation Models binaries]: https://developer.arm.com/products/system-design/fixed-virtual-platforms
[README.md]: ../README.md
