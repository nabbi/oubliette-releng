#! /usr/bin/env bash
# naming upstreams inital seed stage3 as our own speeds up
# session resume without need to tweak the spec files

# download <arch> <upstream profile> <rel_type suffix> [our name for the profile]
download() {
    local arch=$1
    local profile=$2
    local dir="/var/tmp/catalyst/builds/23.0-${3}"
    local as=${4:-${profile}}

    local url="https://distfiles.gentoo.org/releases/${arch}/autobuilds"
    local latest=$(curl -s ${url}/latest-stage3-${arch}-${profile}.txt | grep "stage3-${arch}-${profile}" | awk '{print $1 '})
    local myseed=$(echo ${latest} | sed "s/${arch}-${profile}-/${arch}-oubliette-${as}-/" | sed 's:^.*/::')

    if [[ ! -f ${dir}/${myseed} ]]; then
        echo "Fetching new ${latest} as ${myseed}"
        mkdir -p ${dir} > /dev/null
        curl -s ${url}/${latest} -o ${dir}/${myseed}
    else
        echo "${arch} ${profile} (autobuild ${latest}) is current"
    fi
}

#download amd64 hardened-openrc hardened   # merged-usr 23.0-hardened set, not built
# no hardened split-usr autobuild upstream; stage1 rebuilds it under split-usr/hardened
download amd64 openrc-splitusr hardened-splitusr hardened-openrc-splitusr
#download amd64 musl-hardened musl-hardened
#download amd64 openrc default

#download arm64 openrc default
