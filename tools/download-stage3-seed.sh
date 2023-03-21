#! /usr/bin/env bash
# naming upstreams inital seed stage3 as our own speeds up
# session resume without need to tweak the spec files

download() {
    local arch=$1
    local profile=$2
    local dir=/var/tmp/catalyst/builds/$3

    local url="https://distfiles.gentoo.org/releases/${arch}/autobuilds"
    local latest=$(curl -s ${url}/latest-stage3-${arch}-${profile}.txt | tail -n 1 | awk '{print $1 '})
    local myseed=$(echo ${latest} | sed "s/${arch}-/${arch}-oubliette-/" | sed 's:^.*/::')

    if [[ ! -f ${dir}/${myseed} ]]; then
        echo "Fetching new ${latest} as ${myseed}"
        mkdir -p ${dir} > /dev/null
        curl -s ${url}/${latest} -o ${dir}/${myseed}
    else
        echo "${arch} ${profile} (autobuild ${latest}) is current"
    fi
}

download amd64 hardened-openrc hardened
download amd64 musl-hardened musl-hardened
#download amd64 openrc default

download arm64 openrc default
