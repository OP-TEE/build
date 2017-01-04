Frequently Asked Questions
===========================
1.  [Source code](#1-source-code)
2.  [Building](#2-building)
3.  [License](3-license)
4.  [Contribution, Promotion and security flaws](#4-contribution-promotion-and-security-flaws)
5.  [Certification and security reviews](#5-certification-and-security-reviews)
6.  [Interfaces](#6-interfaces)
7.  [Architecture](#7-architecture)
8.  [Trusted Applications](#8-trusted-applications)
9.  [Testing](#9-testing)


1. Source code
--------------
### Where is the source code?
- It is located on GitHub under the project [OP-TEE].
- Then besides the main gits at [OP-TEE] we also have some other gits used in
  one or another way by OP-TEE at [linaro-swg].

### Where do I download the test suite called xtest?
- All the source code for that can be found in the git called [optee_test].
- The GlobalPlatform extension, [TEE Initial Configuration Compliance Test Suite v1.x],
  can be purchased separately.

### Why isn’t the kernel driver in the vanilla kernel at kernel.org?
Since the beginning of 2015 we have been trying to get our driver mainlined.
This seems to be more challenging than we initially could foresee. If you have
time and interest, please review and test the patches. A list of all patches
submitted could be found at the [Generic TEE driver patches] patchwork page.


2. Building
-----------
### I got build errors running latest, why?
- What did you try to build? Only [optee_os]? A full setup using QEMU, HiKey,
  RPi3, Juno using repo? AOSP? OpenEmbedded? What we build on daily basis are
  the [OP-TEE repo setups], other builds like AOSP and OpenEmbedded are builds
  that we try from time to time, but not very often within Security Working
  Group. Having that said there are other teams in Linaro working with such
  builds, but they most often base their builds on OP-TEE stable releases.

- By running latest instead of stable also comes with a risk of getting build
  errors due to version and/or interdependency skew which can result in build
  error. Now, such issues most often affects running xtest and not the building.
  If you however clean all gits and do a `repo sync -d`. Then we're almost 100%
  sure you will get back to a working state again, since as mentioned in next
  bullet, we build (and run xtest) on all QEMU on all patches sent to OP-TEE.

- Every pull request in OP-TEE are built for a multitude of different platforms
  automatically using [Travis for OP-TEE]. Please have a look there to see
  whether it failed building on the platform you're using before submitting any
  issue about build errors.

### I got build errors running stable tag x.y.z, why?
Stable releases are quite well tested both in terms of building for all
supported platforms and running xtest on all platforms, so if you can't get that
to build and run, then there is a great chance you have something wrong on your
side. All platforms that has been tested on a stable release can be found in
[CHANGELOG.md] file.

### I get `gcc XYZ` or `g++ XYZ` compiler error messages?
Most likely you're trying to build OP-TEE using the regular x86 compiler and not
the using the ARM toolchain. Please install the [OP-TEE pre-requisties] and this
time try to ensure that you are using GCC for ARM (for more information, please
see [Issue#846]).

### I can't get OP-TEE to build using GCC 6.x?
GCC 6.x isn't currently supported, please see [Issue#1200] for more information.

### I found this build.git, what is that?
That git is used in conjunction with the [OP-TEE repo setups]. It contains
helper makefiles that makes it easy to get OP-TEE up and running on the setups
that are using repo.

### When running `make` from build.git it fails to download the toolchains?
We try to stay somewhat up to date with running later gcc versions. But just
like everywhere else on the net things moves around. In some cases like
[Issue#1195], the URL was changed without us noticing it. If you find and fix
such an issue, please send the fix as pull request and we will be happy to merge
it.

### What is the quickest and easiest way to try OP-TEE?
That would be running it on QEMU on a local PC. To do that you would need to:
- Install the [OP-TEE pre-requisties], see section 4.1.
- Configure repo as described in [OP-TEE repo setups], see section 5.1, 5.2.
- Build QEMU, see section 5.3.
- [Run xtest], see section 6.

By summarizing the above, you'd need to:
```bash
$ sudo apt-get install [pre-reqs]
$ mkdir optee-qemu && cd optee-qemu
$ repo init -u https://github.com/OP-TEE/manifest.git
$ repo sync
$ cd build
$ make toolchains
$ make all run
(qemu) c
root@Vexpress:/ tee-supplicant &
root@Vexpress:/ xtest

```


3. License
----------
### Under what license is OP-TEE released?
- Mostly under BSD 2-Clause, see the [LICENSE] file.
- The TEE kernel driver is released under GPLv2 for obvious reasons.
- xtest uses BSD 2-Clause for code running in secure world (Trusted Applications
  etc) and GPLv2 for code running in normal world (client code).

### GlobalPlatform click-through license
Since OP-TEE is a GlobalPlatform based TEE which implements the APIs as
specified by GlobalPlatform one has to accept, the click-through license which
is presented when trying to download the [GlobalPlatform specifications] before
start using OP-TEE.

### I've modified OP-TEE by using code with non BSD 2-Clause license, will you accept it?
That is something we deal with case by case. But as a general answer, if it
doesn't contaminate the BSD 2-Clause license we will accept it. Send us an email
or file an issue at [OP-TEE Issues].


4. Contribution, Promotion and security flaws
---------------------------------------------
### How do I contribute?
Please see the section “Contributions” in the file [Notice.md] at the GitHub
project page.

### Where can I get help?
Via one of the avenues below:
- Create a new issue for a relevant repository on our GitHub site, such as
  [OP-TEE Issues] for example.
- `#linaro-security` IRC channel (`url: irc.linaro.org` or `irc.freenode.net`, `ssl:
   yes, port: 6697`)
- Email: `<op-tee at linaro dot org>`
- For Linaro member companies, please use the [LDTS] page.

### I'm new to OP-TEE but I would like to help out, what can I do?
- We always need help with code reviews, feel free to review any of the open
  [OP-TEE Pull Requests]. Please also note that there could be open pull request
  in the other [OP-TEE] gits that needs review too.
- We always need help answering all the questions asked at [OP-TEE Issues].
- If you want to try to solve a bug, please have a look at the [OP-TEE Bugs] or
  the [OP-TEE Enhancements].
- Documentation tends to become obsolete if not maintained on regular basis. We
  try to do our best, but we're not perfect. Please have a look at
  [OP-TEE Documentation] and try to update where you find gaps.
- Enable `repo` for the device in [Platforms Supported] currently not using
  repo.
- If you'd like to implement a bigger feature, please reach out to us and we can
  discuss what is most relevant to look into for the moment. If you already have
  an idea, feel free to send the proposal to us.

### I want to get my company logo on op-tee.org, how?
If your company has done significant contributions to OP-TEE, then please send
us an email and we will do our best to include your company. Pay attention to
that we will review this on regular basis and inactive supporting companies
might be removed in the future again.

### I have a found a security flaw in OP-TEE, how can I disclose it with you?
Send an email to us (see the About page), where you mention that you've found a
vulnerability, no details are needed in this first email. After that someone in
the team will contact you and let you know how to continue the communication
securely.


5. Certification and security reviews
-------------------------------------
### Will linaro be involved in GlobalPlatform certification/qualification?
No we will not, mainly for two reasons. The first is that there was a board
decision that Security WG in Linaro should not be part of certifications. The
second reason is that most often certification is done using a certain software
version and on a unique device. I.e., it's the combination software + hardware
that gets certified. Since Linaro have no own devices in production or for sale,
we cannot be part of any certification. This is typically something that the SoC
or OEM needs to do.

But since OP-TEE is coming from a proprietary TEE solution that was
GlobalPlatform certified on some products in the past and we regularly have
people from some member companies running the extended test suite from
GlobalPlatform we know that the gap to become GlobalPlatform certified/qualified
isn’t that big.

### Have any test lab been testing OP-TEE?
[Applus Laboratories] have done some side-channel attack testing and fault
injection testing on OP-TEE using the [HiKey]. Their findings will be included
at the [Security Advisories] page at op-tee.org.

### Have there been any code audit / code review done?
- Audit, no! Not something initiated by Linaro. But there has been some
  companies that have done audits internally and they have then shared the
  result with us and where relevant, we have created patches resolving the
  issues reported to us.
- Code review, yes! Every single patch going into OP-TEE has been reviewed in
  a pull request on GitHub. We more or less have a requirement that every patch
  going into OP-TEE shall at least have one "Reviewed-by" tag in the patch.
- Third party / test lab code review, no! Again some companies have reviewed
  internally and shared the result with us, but other than that no.


6. Interfaces
-------------
### What API’s have been implemented in OP-TEE?
- GlobalPlatform’s TEE Client API v1.1 specification
- GlobalPlatform’s TEE Internal Core API v1.1 specification.
- GlobalPlatform’s Secure Elements v1.0
- GlobalPlatform’s Trusted UI v1.0 (implementation not complete).

All those specification can be found at [GlobalPlatform specifications] page.

### Can I use my own hardware IP for crypto acceleration?
Yes, OP-TEE has a [Crypto Abstraction Layer] that was designed mainly to make it
easy to add support for hardware crypto acceleration. There you will find
information about the abstraction layer itself and what you need to do to be
able to support new software/hardware “drivers” in OP-TEE.


7. Architecture
---------------
### Which architectures are supported?
The [Platforms Supported] page lists all platforms and architectures currently
supported in the official tree.

### 32-bit and/or 64-bit support?
Both 32- and 64-bit are fully supported for all OP-TEE components.

**To-Do** mention the configuration flags for NW/SW/TEE/TA etc.

### Does OP-TEE support mixed-mode, i.e., both AArch32 and AArch64 Trusted Applications on top of an AArch64 core?
Yes!

### How do I port OP-TEE to another platform?
- Start by reading the [LCU14-302 How To Port OP-TEE To Another Platform] deck
  and have a look at the [LCU14-302 YouTube clip] that complements the deck.
  Beware that the presentation is more than three years old, so even though it's
  a good source, there might be parts that are not relevant any longer.
- As a good example for an **ARMv8-A** patch enabling OP-TEE support on a new
  device, please see the [ZynqMP port] that enabled support for running OP-TEE on
  Xilinx UltraScale+ Zynq MPSoC. Besides that there are similar patches for [Juno
  port], [Raspberry Pi3 port], [HiKey port].
- And for **ARMv7-A**, please have a look at the [Freescale ls1021a port],
  another example would be the [TI DRA7xx port].

### What’s the maximum size for heap and stack? Can it be changed?
Yes, it can be changed. In the current setup (for vexpress for example), there
are `32MB DDR` dedicated for OP-TEE. `1MB` for `TEE RAM` and `1MB` for `PUB
RAM`, this leaves `30MB` for Trusted Applications. In the Trusted Applications,
you set `TA_DATA_STACK` and `TA_DATA_SIZE`. Typically, we set stack to `1KB` and
data to `32K`. But you are free to adjust those according to the amount of
memory you have available. If you need them to be bigger than `1MB` then you
also must adjust TA’s MMU L1 table accordingly, since default section mapping is
1MB.

### What is the size of OP-TEE itself?
As of 2016.01, optee_os is about `244KB` (release build). It is preferred to
store [optee_os] in SRAM, but if there is not enough room, DRAM can be used and
protected with TZASC. We are also looking into the possibility of creating a
‘minimal’ OP-TEE, i.e. a limited OP-TEE usable even in a very memory constrained
environment, by eliminating as many memory-hungry parts as possible. There is
however no ETA for this at the moment.

You can check the memory usage by using the `make mem_usage` target in
[optee_os], example:

```
$ make ... mem_usage

# Which will output a file with the figures here:
# out/arm/core/tee.mem_usage
```
You will of course get different sizes depending on what compile time flags you
have enabled when running `make mem_usage`.

### Can NEON optimizations be done in OP-TEE?
Yes, but it will require implementation of lazy context switching which Linaro
is currently working on as part of the work to add support for ARMv8-A Crypto
Extensions. You can read more about [Lazy Context Switching] at the ARM pages.
Please also see [Issue#953].

### Can I use C++ libraries in OP-TEE?
C++ libraries are currently not supported. Technically, it is possible but will
require a fair amount of work to implement, especially more so if exceptions are
required. There are currently no plans to do this.

### Would using `malloc()` in OP-TEE give physically contiguous memory?
`malloc()` in OP-TEE currently gives physically contiguous memory. It is not
guaranteed as it is not mentioned anywhere in the documentation, but in practice
the heap only has physically contiguous memory in the pool(s). The heap in
OP-TEE is normally quite small, ~24KiB, and could be a bit fragmented.

### Can I limit what CPUs / cores OP-TEE runs on?
Currently it’s up to the kernel to decide which core it runs on, i.e, it will be
the same core as the one initiating the SMC in Linux. Please also see
[Issue#1194].

### How is OP-TEE being scheduled?
OP-TEE doesn't have its own scheduler, instead it's being scheduled by Linux
kernel. For more information, please see [Issue#1036], [Issue#1183].


8. Trusted Applications
-----------------------
### How do I write a Trusted Application (TA)?
- Start by reading the [LCU14-103 How to create and run Trusted Applications on
  OP-TEE] deck and have a look at the [LCU14-103 YouTube clip] that that
  complements the deck. Word of warning, the deck is more than three years old,
  so maybe not everything said there is valid as of today.
- Since that talk, the [Hello World Trusted Application] has been officially
  included in the [OP-TEE repo setups]. I.e., don't refer to the URL in the deck
  any longer since it is obsolete.
- If you want to see more advanced uses cases of Trusted Applications, then we
  encourage that you have a look at the [TAs in xtest].

### How do I link a library into a Trusted Application?
**To-Do** add more text, but see [Issue#280], [Issue#601], [Issue#901],
[Issue#1003] for now.

### Where should I store my Trusted Application on the device?
`/lib/optee_armtz`, that is the default configuration where tee-supplicant will
look for Trusted Applications.

### What is a Static TA and how do I write one?
A Static TA is a Trusted Application that runs in TEE kernel / core context.
I.e., it will have access to the same functions, memory and hardware etc as the
TEE core itself. If we're talking ARMv8-A it is running in S-EL1.

### Are Static **user space** TAs supported?
No!

### Can a static TA Open/Invoke dynamic TA?
Yes, for a longer discussion see [Issue#967], [Issue#1085], [Issue#1132].

### What can I do to access specific functionalities not part of the GP internal API?
You may develop your own “static TA”, which is part of the core (see above for
more information about the Static TA).

### How are Trusted Applications verified?
In the current solution all TAs are signed ([sign.py]) with the same RSA key
([default_ta.pem]). This works as long as the end user is in charge of the
system. But for a setup involving third parties, there is a need for a better
way to deal with this. We have started to look into various ideas and one of
them is [OTrP].

If the user will use the current implementation he **MUST** replace the
[default_ta.pem] with a new key. [default_ta.pem] should only be seen as a test
key!

### Is multi-core TA supported?
Yes, you can have two or more TAs running simultaneously. Please see also
[Issue#1194].

### Is multi-threading supported in a TA?
No, there is no such concept as pthreads or similar. I.e, you cannot spawn
thread from a TA. If you need to run tasks in parallel, then you should
probably look into running two TAs or more simultaneously and then let them
communicate with each other using the TA2TA interface.

### I've heard that there is a Widevine and PlayReady TA, how do I get access?
Those can only be shared are under NDA with Google and Microsoft. Linaro can
help members of Linaro to get access to those. Non-member access needs to be
dealt with on case by case basis.

9. Testing
----------
### How are you testing OP-TEE?
There is a test suite called xtest ([optee_test]) that tests the complete
TEE-solution to ensure that the communication between all architectural layers
is working as it should. The test suite also tests the majority of the
GlobalPlatform TEE Internal Core API. It has close to 50,000 and ever increasing
test cases, and is also extendable with the official GlobalPlatform test suite
(see [TEE Initial Configuration Compliance Test Suite v1.x]).

Also every single pull request in OP-TEE are being tested automatically on QEMU
using [Travis for OP-TEE].

# Abbreviations
- OP-TEE: Open Portable TEE
- TEE: Trusted Execution Environment
- TA: Trusted Application
- TZASC: TrustZone Address Space Controller
- TZPC: TrustZone Protection Controller


[Applus Laboratories]: http://www.appluslaboratories.com
[build.git]: https://github.com/OP-TEE/build
[CHANGELOG.md]: https://github.com/OP-TEE/optee_os/blob/master/CHANGELOG.md
[Crypto Abstraction Layer]: https://github.com/OP-TEE/optee_os/blob/master/documentation/crypto.md
[default_ta.pem]: https://github.com/OP-TEE/optee_os/blob/master/keys/default_ta.pem
[Freescale ls1021a port]: https://github.com/OP-TEE/optee_os/commit/85278139a8f914dddb36808861c86a472ecb0271
[Generic TEE driver patches]: https://patchwork.kernel.org/project/linux-arm-kernel/list/?submitter=129291
[GlobalPlatform specifications]: http://www.globalplatform.org/specificationsdevice.asp
[Hello World Trusted Application]: https://github.com/linaro-swg/hello_world
[HiKey]: http://www.96boards.org/product/hikey
[HiKey port]: https://github.com/OP-TEE/optee_os/commit/d70e78c49fc9c63b2d37c596b7ad3cbd38f8e574
[Juno port]: https://github.com/OP-TEE/optee_os/commit/90e7497e0480892e2c262cec64e6c47242d4db7f
[Lazy Context Switching]: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.prd29-genc-009492c/ch05s03s01.html
[LCU14-302 How To Port OP-TEE To Another Platform]: http://www.slideshare.net/linaroorg/lcu14-302-how-to-port-optee-to-another-platform
[LCU14-302 YouTube clip]: http://www.youtube.com/watch?v=QgaGJow7hws
[LCU14-103 How to create and run Trusted Applications on OP-TEE]: http://www.slideshare.net/linaroorg/lcu14103-how-to-create-and-run-trusted-applications-on-optee
[LCU14-103 YouTube clip]: http://www.youtube.com/watch?v=6fmwhqrOmpc
[LDTS]: https://support.linaro.org
[linaro-swg]: https://github.com/linaro-swg
[LICENSE]: https://github.com/OP-TEE/optee_os/blob/master/LICENSE
[Notice.md]: https://github.com/OP-TEE/optee_os/blob/master/Notice.md
[optee_os]: https://github.com/OP-TEE/optee_os
[optee_test]: https://github.com/OP-TEE/optee_test
[OP-TEE]: https://github.com/OP-TEE
[OP-TEE Bugs]: https://github.com/OP-TEE/optee_os/labels/bug
[OP-TEE Documentation]: https://github.com/OP-TEE/optee_os/tree/master/documentation
[OP-TEE Enhancements]: https://github.com/OP-TEE/optee_os/labels/enhancement
[OP-TEE Issues]: https://github.com/OP-TEE/optee_os/issues
[OP-TEE pre-requisties]: https://github.com/OP-TEE/optee_os#41-prerequisites
[OP-TEE Pull Requests]: https://github.com/OP-TEE/optee_os/pulls
[OP-TEE repo setups]: https://github.com/OP-TEE/optee_os#5-repo-manifests
[OTrP]: https://tools.ietf.org/html/draft-pei-opentrustprotocol-01
[Platforms Supported]: https://github.com/OP-TEE/optee_os#3-platforms-supported
[Raspberry Pi3 port]: https://github.com/OP-TEE/optee_os/commit/66d9cacf37e6bd4b0d86e7b32e4e5edefe8decfd
[Run xtest]: https://github.com/OP-TEE/optee_os#6-load-driver-tee-supplicant-and-run-xtest
[Static TA examples]: https://github.com/OP-TEE/optee_os/tree/master/core/arch/arm/sta
[sign.py]: https://github.com/OP-TEE/optee_os/blob/master/scripts/sign.py
[TAs in xtest]: https://github.com/OP-TEE/optee_test/tree/master/ta
[TEE Initial Configuration Compliance Test Suite v1.x]: https://www.globalplatform.org/storecontent.asp?show=testsuites
[TI DRA7xx port]: https://github.com/OP-TEE/optee_os/commit/9b5060cd92a19b4d114a1ce8a338b18424974037
[Travis for OP-TEE]: https://travis-ci.org/OP-TEE/optee_os/builds
[ZynqMP port]: https://github.com/OP-TEE/optee_os/commit/dc57f5a0e8f3b502fc958bc64a5ec0b0f46ef11a

[Issue#280]: https://github.com/OP-TEE/optee_os/issues/280
[Issue#601]: https://github.com/OP-TEE/optee_os/issues/601
[Issue#846]: https://github.com/OP-TEE/optee_os/issues/846
[Issue#901]: https://github.com/OP-TEE/optee_os/issues/901
[Issue#953]: https://github.com/OP-TEE/optee_os/issues/953
[Issue#967]: https://github.com/OP-TEE/optee_os/issues/967
[Issue#1003]: https://github.com/OP-TEE/optee_os/issues/1003
[Issue#1036]: https://github.com/OP-TEE/optee_os/issues/1036
[Issue#1085]: https://github.com/OP-TEE/optee_os/issues/1085
[Issue#1132]: https://github.com/OP-TEE/optee_os/issues/1132
[Issue#1183]: https://github.com/OP-TEE/optee_os/issues/1183
[Issue#1194]: https://github.com/OP-TEE/optee_os/issues/1194
[Issue#1195]: https://github.com/OP-TEE/optee_os/issues/1195
[Issue#1200]: https://github.com/OP-TEE/optee_os/issues/1200
