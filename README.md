# Oubliette Releases

These are my unofficial Catalyst build specs, modified from [Gentoo's Releng](https://gitweb.gentoo.org/proj/releng.git), for creating custom releases based on Gentoo Linux.

## AMD64 Admin ISO

* kconfig: resolves usb keyboard initialization issue on one of my systems
* livecd: auto-start sshd with key auth from `overlay/admincd/root/.ssh/authorized_keys` when it exists locally (gitignored); start from `authorized_keys.example` next to it
* livecd: auto-join wifi when `overlay/admincd/etc/wpa_supplicant/wpa_supplicant.conf` exists locally (gitignored, never committed); start from `wpa_supplicant.example.conf` next to it
* livecd and framework stage4: trust local CAs from `overlay/<image>/usr/local/share/ca-certificates/*.crt` when they exist locally (gitignored); see `local-ca.crt.example` next to them
* livecd: chronyd at boot, so stage signatures and TLS see a sane clock
* livecd: mosh for flaky (wifi) admin sessions
* livecd: boots with overlayfs over the squashfs, no copy of /etc, /var, ... to tmpfs
* livecd: includes more packages - mostly network focused
* linux-firmware: pruned via savedconfig (no AMD/NVIDIA GPU, DVB or Qualcomm SoC `qcom/` blobs; Intel `i915/` and `xe/` are kept for the admincd's Intel GPU drivers) to save space; the same list feeds the untested arm64 stage4, so Qualcomm arm64 boards get no `qcom/` firmware
* distcc support
* incorporates Oubliette [overlay](https://github.com/nabbi/oubliette-overlay) and [patches](https://github.com/nabbi/oubliette-patches)

## AMD64 Server Stage4

* base stage3 plus a few common packages which I tend to use

## ARM64

* incomplete experimental (abandoned)

## build system packages note

These spec and conf files are incompatible with previous stable catalyst-3.0.17 branch, tested with catalyst-9999 Sept 2021

# initial setup

```shell
git clone https://github.com/nabbi/oubliette-releng
cd oubliette-releng
git submodule update --init --recursive 
```

## time

catalyst-auto depends on time for statistical process reporting, but it cannot call the bash built in time command

```shell
sudo emerge -qva sys-process/time
```

## distcc config

./config/catalyst.conf needs to be defined from catalyst.example.conf, adjust distcc servers as needed

Copy this file into /etc/catalyst/catalyst.conf

## add oubliette overlay

The spec files expect default paths at /var/db/repos/oubliette

```shell
sudo eselect repository enable oubliette
```


# run catalyst-auto via build script

```shell
sudo ./tools/oubliette-build.sh
```


A failed build is resumed on the next run: specs whose output already exists
are skipped and the failed spec continues via catalyst autoresume. Runs older
than 72 hours are discarded and rebuilt from scratch.

```shell
sudo ./tools/oubliette-build.sh --full          # force a clean rebuild
sudo ./tools/oubliette-build.sh --max-age 24    # only resume runs < 24h old
```

Follow a running build from another terminal:

```shell
sudo ./tools/oubliette-watch.sh            # progress notes: steps, emerge (n of m), errors
sudo ./tools/oubliette-watch.sh --status   # one-shot built/building/failed/pending summary
sudo ./tools/oubliette-watch.sh --raw      # full log of the current spec
sudo ./tools/oubliette-watch.sh --pkg      # build.log of the package compiling in the chroot
```
