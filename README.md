# Oubliette Releases

These are my unofficial Catalyst build specs, modified from [Gentoo's Releng](https://gitweb.gentoo.org/proj/releng.git), for creating custom releases based on Gentoo Linux.

## AMD64 Admin ISO

* kconfig: resolves usb keyboard initialization issue on one of my systems
* livecd: auto-start sshd using my public key for auth
* livecd: includes more packages - mostly network focused
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

