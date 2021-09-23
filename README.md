# Oubliette Releases

These are my unofficial Catalyst build specs, modified from [Gentoo's Releng](https://gitweb.gentoo.org/proj/releng.git), for creating Gentoo Linux media releases.


## AMD64 Admin ISO

* kconfig: resolves usb keyboard initialization issue on one of my systems
* livecd: auto-start sshd using my public key for auth
* livecd: includes more packages - mostly network focused
* distcc support
* incroporates Oubliette [overlay](https://github.com/nabbi/oubliette-overlay) and [patches](https://github.com/nabbi/oubliette-patches)

## AMD64 Server Stage4

* base stage3 + common packages which I use

## ARM64

* incomplete experimental


## build system packages note

These spec and conf files are incompatible with previous stable catalyst-3.0.17 branch, tested with catalyst-9999 Sept 2021


# initial setup

I haven't quite deciphered how release team translates @vars@ in spec files, I pathed these under /opt/ for my own convenience

> git clone https://github.com/nabbi/oubliette-releng /opt/oubliette-releng
> cd /opt/oubliette-releng
> git submodule update --init --recursive 

## distcc config

./config/catalyst.conf needs to be defined from catalyst.example.conf, adjust distcc servers as needed

## download stage3 seed

# http://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/

> mkdir -p /var/tmp/catalyst/builds/hardened
> cd /var/tmp/catalyst/builds/hardened
> wget http://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-20210912T170541Z.tar.xz
> ln -s stage3-amd64-hardened-openrc-20210912T170541Z.tar.xz gentoo-stage3-amd64-hardened-openrc-latest.tar.xz

## clone portage git repo

> mkdir -p /var/tmp/catalyst/repos/
> git clone https://anongit.gentoo.org/git/repo/gentoo.git /var/tmp/catalyst/repos/gentoo.git



# run catalyst build phases


## update snapshot

> cd /var/tmp/catalyst/repos/gentoo.git
> git pull

## create snapshot

> cd /opt/oubliette-releng
> catalyst -s master -c config/catalyst.conf

## stages

> cd /opt/oubliette-releng
> catalyst -f releases/specs/amd64/hardened/stage1-openrc.spec -c config/catalyst.conf
> catalyst -f releases/specs/amd64/hardened/stage2-openrc.spec -c config/catalyst.conf
> catalyst -f releases/specs/amd64/hardened/stage3-openrc.spec -c config/catalyst.conf

## admincd

> catalyst -f releases/specs/amd64/hardened/admincd-stage1.spec -c config/catalyst.conf
> catalyst -f releases/specs/amd64/hardened/admincd-stage2.spec -c config/catalyst.conf

