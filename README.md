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

I cloned this repo locally under /opt

```shell
git clone https://github.com/nabbi/oubliette-releng /opt/oubliette-releng
cd /opt/oubliette-releng
git submodule update --init --recursive 
```

## time

catalyst-auto depends on time for statistical process reporting, but it cannot call the bash built in time command

```shell
emerge -qva sys-process/time
```

## distcc config

./config/catalyst.conf needs to be defined from catalyst.example.conf, adjust distcc servers as needed

Copy this file into /etc/catalyst/catalyst.conf

## download latest stage3 seed


```shell
./tools/download-stage3-seed.sh
```

## add oubliette overlay

The spec files expect default paths at /var/db/repos/oubliette

```shell
eselect repository enable oubliette
```


# run catalyst-auto

```shell
./tools/catalyst-auto -X -v -c tools/catalyst-auto-amd64.conf
```

