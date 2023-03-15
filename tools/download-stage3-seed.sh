#! /usr/bin/env bash

URL='https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/'

SEED=$(curl -s $URL | grep "stage3-amd64-hardened-openrc.*.tar.xz<" | sed 's/^.*href="//' | sed 's/">.*$//')

DIR=/var/tmp/catalyst/builds/hardened
mkdir -p $DIR > /dev/null

if [[ ! -f $DIR/$SEED ]]; then
    echo "Fetching new $SEED"
    curl -s $URL/$SEED -o $DIR/$SEED
else
    echo "$SEED is already latest"
fi
