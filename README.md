# OP-TEE build.git

## Contents
1. [Introduction](#1-introduction)
2. [Why repo?](#2-why-repo)
3. [Here is bunch of other stuff in this git to, why?](#3-here-is-bunch-of-other-stuff-in-this-git-to-why)
4. [How do I build using AOSP / OpenEmbedded?](#4-how-do-i-build-using-aosp--openembedded)
5. [Platforms supported by build.git](#5-platforms-supported-by-buildgit)
6. [Manifests](#6-manifests)
7. [Get and build the solution](#7-get-and-build-the-solution)
8. [FAQ](#8-faq)

# 1. Introduction
Why this particular git? Well, as it turns out it's totally possible to put
together everything on your own. You can build all the individual components,
os, client, xtest, Linux kernel, ARM-TF, TianoCore, QEMU, BusyBox etc and put
all the binaries at correct locations and write your own command lines,
Makefiles, shell-scripts etc that will work nicely on the devices you are
interested in. If you know how to do that, fine, please go a head. But for
newcomers it's way to much behind the scenes to be able to setup a working
environment. Also, if you for some reason want to run something in an automated
way, then you need something else wrapping it up for you.

With this particular git **built.git** our goal is to:<br>
**Make it easy for newcomers to get started with OP-TEE using the devices we've
listed in this document.**

# 2. Why repo?
We discussed alternatives, initially we started out with having a simple
shell-script, that worked to start with, but after getting more gits in use and
support for more devices it started to be difficult to maintain. In the end we
ended up choosing between [repo] from the Google AOSP project and [git
submodules]. No matter which you choose, there will always be some person
arguing that one is better than the other. For us we decided to use repo. Not
directly for the features itself from repo, but for the ability to simply work
with different manifests containing both stable and non-stable release. Using
some tips and tricks you can also speed up setup time significantly. For day to
day work with commits, branches etc we tend to use git commands directly.

# 3. Here is bunch of other stuff in this git to, why?
If we count the number of gits used in for example a QEMU based OP-TEE setup we
have 14 different gits in use. Either we document tiny bits in each git or we
try to combine as much as possible in a common place. We believe it's better to
combine as much as possible, so that it should be easy for the user of OP-TEE to
know where to look for information. We've discussed the option of having some
information at optee.org, but we concluded that it's quite nice to have it in
some of our source code gits, so that the documentation is accurate for a
certain version of OP-TEE. I.e, step back to an older stable release and the
documentation in the git will reflect the current state at that point in time.
So, this particular git, will contain information about how to build, deploy
and test OP-TEE on some devices that we have in our possession. The builds that
we cover here are as small as possible and is based on an initramfs based
filesystem (using BusyBox) and the least amount of gits needed to boot up and
run xtest. Since we are using repo, we will also list and describe the
manifests we are using here.

Besides that, this git also contains information that are device specific, it
could be as simple as some tips and tricks or for example how to run JTAG on a
certain device. We've also put the entire [FAQ] in this git.

# 4. How do I build using AOSP / OpenEmbedded?
It's possible, we have teams in Linaro doing that and we even have some limited
experience doing such builds in the OP-TEE team. But, both of those builds are
rather big and is a bit too much for us on daily basis. AOSP easily ends up with
+80GB builds which takes hours and OE builds we've tried ends up with 15-20GB
and also takes quite some time. Eventually we will point to some guide in the
future or we will include it as a subsection or something in this git.

# 5. Platforms supported by build.git
Below is a table showing the platforms supported by build.git. OP-TEE as such
supports many more platforms, but since quite a few of the other platforms are
maintained by people outside Linaro or are using a special setup, we encourage
you to talk to the maintainer of that platform directly if you have build
related questions etc. Please see the [MAINTAINERS] file for contact
information.

<!-- Please keep this list sorted in alphabetic order -->
| Platform | Composite PLATFORM flag | Publicly available? |
|----------|-------------------------|---------------------|
| [ARM Juno Board](http://www.arm.com/products/tools/development-boards/versatile-express/juno-arm-development-platform.php) |`PLATFORM=vexpress-juno`| Yes |
| [ARM Foundation FVP](http://www.arm.com/fvp) |`PLATFORM=vexpress-fvp`| Yes |
| [HiKey Board (HiSilicon Kirin 620)](https://www.96boards.org/products/hikey)|`PLATFORM=hikey`| Yes |
| [MediaTek MT8173 EVB Board](http://www.mediatek.com/en/products/mobile-communications/tablet/mt8173)|`PLATFORM=mediatek-mt8173`| No |
| [Poplar](https://www.96boards.org/product/poplar/)|`PLATFORM=poplar`| Yes |
| [QEMU](http://wiki.qemu.org/Main_Page) |`PLATFORM=vexpress-qemu_virt`| Yes |
| [QEMUv8](http://wiki.qemu.org/Main_Page) |`PLATFORM=vexpress-qemu_armv8a`| Yes |
| [Raspberry Pi 3](https://www.raspberrypi.org/products/raspberry-pi-3-model-b) |`PLATFORM=rpi3`| Yes |
| [Texas Instruments DRA7xx](http://www.ti.com/product/DRA746)|`PLATFORM=ti-dra7xx`| Yes |
| [Texas Instruments AM57xx](http://www.ti.com/product/AM5728)|`PLATFORM=ti-am57xx`| Yes |
| [Texas Instruments AM43xx](http://www.ti.com/product/AM4379)|`PLATFORM=ti-am43xx`| Yes |

# 6. Manifests
## 6.1 Current version
Here is a list of manifests for the devices currently supported in `build.git`.
With these you will get a setup containing the all necessary software
components to run OP-TEE on the chosen device. Beware that this will run latest
available on OP-TEE gits meaning that if you re-sync then you will most likely
get new commits. If you need a stable/tagged version with non-moving gits, then
please refer to the next section instead.

| Target         | Manifest xml   | Device documentation |
|----------------|----------------|----------------------|
| QEMU           | `default.xml`  | [qemu.md]            |
| QEMUv8         | `qemu_v8.xml`  |                      |
| FVP            | `fvp.xml`      | [fvp.md]             |
| HiKey          | `hikey.xml`    | [hikey.md]           |
| HiKey 960      | `hikey960.xml` | [hikey960.md]        |
| Poplar Debian  | `poplar.xml`   |                      |
| ARM Juno board | `juno.xml`     | [juno.md]            |
| Raspberry Pi 3 | `rpi3.xml`     | [rpi3.md]            |
| DRA7xx         | `dra7xx.xml`   | [ti.md]              |
| AM57xx         | `am57xx.xml`   | [ti.md]              |
| AM43xx         | `am43xx.xml`   | [ti.md]              |

## 6.2 Stable releases
Starting from OP-TEE `v3.1` you can check out stable releases by using the same
manifests as for current version above, but with the difference that **you also
need to specify a branch** where the name corresponds to the release version.
I.e., when we are doing releases we are creating a branch with a name
corresponding to the release version. So, let's for example say that you want
to checkout a stable OP-TEE `v3.2` for Raspberry Pi 3, then you do like this
instead of what is mentioned further down in section `7.3` (note the `-b 3.2.0`):
```bash
...
$ repo init -u https://github.com/OP-TEE/manifest.git -m rpi3.xml -b 3.2.0
...
```

## 6.2.1 Stable releases prior to OP-TEE v3.1 (v1.0.0 to v3.0.0)
Before OP-TEE `v3.1` we used to have separate xml-manifest files for the
stable builds. If you for some reason need an older stable release, then you
can use the `xyz_stable.xml` file corresponding to your device. The way to
init `repo` is almost the same as described above, the major difference is the
name of manifest being referenced (`-m xyz_stable.xml`) and that we are
referring to a tag instead of a branch (`-b refs/tags/MAJOR.MINOR.PATCH`). So
as an example, if you need to setup the `2.1.0` stable release for HiKey, then
you would do like this instead of what is mentioned further down in section
`7.3`
```bash
...
repo init -u https://github.com/OP-TEE/manifest.git -m hikey_stable.xml -b refs/tags/2.1.0
...
```

Here is a list of targets and the names of the stable manifests files which
were supported by older releases:

| Target         | Stable manifest xml       |
|----------------|---------------------------|
| QEMU           | `default_stable.xml`      |
| QEMUv8         | `qemu_v8_stable.xml`      |
| FVP            | `fvp_stable.xml`          |
| HiKey          | `hikey_stable.xml`        |
| HiKey Debian   | `hikey_debian_stable.xml` |
| HiKey 960      | `hikey960_stable.xml`     |
| ARM Juno board | `juno_stable.xml`         |
| Raspberry Pi 3 | `rpi3_stable.xml`         |
| DRA7xx         | `dra7xx_stable.xml`       |
| AM57xx         | `am57xx_stable.xml`       |
| AM43xx         | `am43xx_stable.xml`       |

# 7. Get and build the solution
Below we will describe the general way of getting the source, building the
solution and how to run xtest on the device. For device specific instructions,
see the respective `device.md` file in the [docs] folder.

## 7.1 Prerequisites
We believe that you can use any Linux distribution to build OP-TEE, but as
maintainers of OP-TEE we are mainly using Ubuntu-based distributions and to be
able to build and run OP-TEE there are a few packages that needs to be installed
to start with. Therefore install the following packages regardless of what
target you will use in the end.

```bash
$ sudo apt-get install android-tools-adb android-tools-fastboot autoconf \
	automake bc bison build-essential cscope curl device-tree-compiler \
	expect flex ftp-upload gdisk iasl libattr1-dev libc6:i386 libcap-dev \
	libfdt-dev libftdi-dev libglib2.0-dev libhidapi-dev libncurses5-dev \
	libpixman-1-dev libssl-dev libstdc++6:i386 libtool libz1:i386 make \
	mtools netcat python-crypto python-serial python-wand unzip uuid-dev \
	xdg-utils xterm xz-utils zlib1g-dev
```

## 7.2 Install Android repo
Note that here you don't install a huge SDK, it's simply a Python script that
you download and put in your `$PATH`, that's it. Exactly how to "install" repo,
could be found in the Google [repo] pages, so follow those instructions before
continuing.

## 7.3 Get the source code
Choose the manifest corresponding to the platform you intend to use. For
example, if you intend to use Raspberry Pi3, then `${TARGET}.xml` should be
`rpi3.xml`. The `repo sync` step will take some time if you aren't referencing
an existing tree (see Tips and Tricks below).

```bash
$ mkdir -p $HOME/devel/optee
$ cd $HOME/devel/optee
$ repo init -u https://github.com/OP-TEE/manifest.git -m ${TARGET}.xml [-b ${BRANCH}]
$ repo sync
```
## 7.4 Get the toolchains
In OP-TEE we're using different toolchains for different targets (depends on
ARMv7-A ARMv8-A 64/32bit solutions). In any case start by downloading the
toolchains by:
```bash
$ cd build
$ make toolchains
```

## 7.5 Build the solution
We've configured our repo manifests, so that repo will always automatically
symlink the `Makefile` to the correct device specific makefile, that means that
you simply start the build by running:

```bash
$ make
```
This step will also take some time, but you can speed up subsequent builds by
enabling [ccache] (again see Tips and Tricks).

## 7.6 Flash the device
On non-emulated solutions, you will need to flash the software in some way.
We've tried to "hide" that under the following make target:
```bash
$ make flash
```
But, since some devices are trickier to flash than others, please see the device
specific files. See this just as a general instruction.

## 7.7 Boot up the device
This is device specific.

## 7.8 Load tee-supplicant
On some solutions tee-supplicant is already loaded (`$ ps aux | grep
tee-supplicant`) on other not. If it's not loaded, then start it by running:
```bash
$ tee-supplicant &
```
If you've built using our manifest you should not need to modprobe any
OP-TEE/TEE kernel driver since it's built into the kernel in all our setups.

## 7.9 Run xtest
The entire xtest test suite has been deployed when you we're running `$ make
run` in previous step, i.e, in general there is no need to copy any binaries
manually. Everything has been put into the root FS automatically. So, to run
xtest, you simply type:
```bash
$ xtest
```

If there are no regressions / issues found, xtest should end with something like
this:
```bash
+-----------------------------------------------------
23476 subtests of which 0 failed
67 test cases of which 0 failed
0 test case was skipped
TEE test application done!
```

## 7.10 Tips and Tricks
### 7.10.1 Reference existing project to speed up repo sync
Doing a `repo init`, `repo sync` from scratch can take a fair amount of time.
The main reason for that is simply because of the size of some of the gits we
are using, like for the Linux kernel and EDK2. With repo you can reference an
existing forest and by doing so you can speed up repo sync to taking 20 seconds
instead of an hour. The way to do this are as follows.

1. Start by setup a clean forest that you will not touch, in this example, let
   us call that `optee-ref` and put that under for `$HOME/devel/optee-ref`. This
   step will take roughly an hour.
2. Then setup a cronjob (`crontab -e`) that does a `repo sync` in this folder
   particular folder once a night (that is more than enough).
3. Now you should setup your actual tree which you are going to use as your
   working tree. The way to do this is almost the same as stated in the
   instructions above, the only difference is that you reference the other local
   forest when running `repo init`, like this
   ```
   repo init -u https://github.com/OP-TEE/manifest.git --reference /home/jbech/devel/optee-ref
   ```
4. The rest is the same above, but now it will only take a couple of seconds to
   clone a forest.

Normally step 1 and 2 above is something you will only do once. Also if you
ignore step 2, then you will still get the latest from official git trees, since
repo will also check for updates that aren't at the local reference.

### 7.10.2 Use ccache
ccache isfaqa tool that caches build object-files etc locally on the disc and can
speed up build time significantly in subsequent builds. On Debian-based systems
(Ubuntu, Mint etc) you simply install it by running:
```
$ sudo apt-get install ccache
```

The makefiles in build.git are configured to automatically find and use ccache
if ccache is installed on your system, so other than having it installed you
don't have to think about anything.

# 8. FAQ
Please have a look at out [FAQ] file for a list of questions commonly asked.

[ccache]: https://ccache.samba.org
[docs]: docs
[FAQ]: faq.md
[fvp.md]: ./docs/fvp.md
[git submodules]: https://git-scm.com/book/en/v2/Git-Tools-Submodules
[juno.md]: ./docs/juno.md
[hikey.md]: ./docs/hikey.md
[hikey960.md]: ./docs/hikey960.md
[manifest/README.md]: https://github.com/OP-TEE/manifest/blob/master/README.md
[MAINTAINERS]: https://github.com/OP-TEE/optee_os/blob/master/MAINTAINERS
[OP-TEE/README.md]: https://github.com/OP-TEE/optee_os/blob/master/README.md
[qemu.md]: ./docs/qemu.md
[repo]: https://source.android.com/source/downloading.html
[rpi3.md]: ./docs/rpi3.md
[ti.md]: ./docs/ti.md
