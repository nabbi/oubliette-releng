subarch: arm64
target: stage1
version_stamp: oubliette
rel_type: default
profile: default/linux/arm64/17.0
source_subpath: default/gentoo-stage3-arm64
compression_mode: pixz_x
update_seed: yes
update_seed_command: --update --deep --jobs=5 --newuse --complete-graph @world
portage_confdir: @REPO_DIR@/releases/portage/stages
portage_prefix: releng
snapshot_treeish: master
repos: /var/lib/layman/oubliette
