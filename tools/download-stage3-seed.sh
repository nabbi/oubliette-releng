#! /usr/bin/env bash
# naming upstreams inital seed stage3 as our own speeds up
# session resume without need to tweak the spec files

URL='https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/'

SEED=$(curl -s $URL | grep "stage3-amd64-hardened-openrc.*.tar.xz<" | sed 's/^.*href="//' | sed 's/">.*$//')
MYSEED=$(echo $SEED | sed 's/amd64-hardened/amd64-oubliette-hardened/')

DIR=/var/tmp/catalyst/builds/hardened
mkdir -p $DIR > /dev/null

if [[ ! -f $DIR/$MYSEED ]]; then
    echo "Fetching new $SEED"
    curl -s $URL/$SEED -o $DIR/$MYSEED
else
    echo "$SEED is alreay Gentoo's latest autobuild"
fi
