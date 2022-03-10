subarch: amd64
target: stage1
version_stamp: hardened-openrc-oubliette
rel_type: hardened
profile: default/linux/amd64/17.1/hardened
source_subpath: hardened/gentoo-stage3-amd64-hardened-openrc-latest
compression_mode: pixz
update_seed: yes
update_seed_command: --update --deep --newuse @world
portage_confdir: /opt/oubliette-releng/releases/portage/stages
portage_prefix: releng
snapshot_treeish: master
repos: /var/lib/layman/oubliette
