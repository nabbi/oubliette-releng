# kconfig changes

local oubliette changes

```shell
sed -i "s/\(CONFIG_USB_.*HCI.*\)=m/\1=y/" *.config
sed -i 's/^#\ CONFIG_MLX4_EN\ is\ not\ set/CONFIG_MLX4_EN=m/' *.config
sed -i 's/^#\ CONFIG_MLX4_CORE_GEN2\ is\ not\ set/CONFIG_MLX4_CORE_GEN2=m/' *.config
```

## Configs

| Config | Spec | Built from |
|--------|------|------------|
| `amd64-7.2.8-admincd.config` | `admincd-stage2.spec` | previous admincd config (from the `amd64-6.6.30.config` cloud baseline) + `fragments/admincd.config` |
| `fragments/framework.config` | `stage4-openrc-23-framework.spec` | dist-kernel fragment: catalyst copies it to `/etc/kernel/config.d/`, gentoo-kernel merges it onto the Gentoo dist config + hardened-base |

`fragments/admincd.config` is generic hardware compatibility only (GOP console via
simpledrm, Intel i915/xe for backlight control, IOMMU interrupt remapping, newer Intel
platforms, Wi-Fi 7, USB4, I2C HID touchpads). Native GPU drivers must match the ISO's
linux-firmware: i915/xe/amdgpu evict the firmware framebuffer before failing on missing
firmware, leaving a blank screen. The isos savedconfig keeps `i915/` and `xe/` for that
reason; amdgpu/nouveau stay out because their firmware is pruned. Anything
machine-specific goes in that machine's fragment and only its stage4.

Regenerate against a clean gentoo-sources tree (not one built in place) after a kernel bump:

```shell
cd <clean gentoo-sources tree>
cp <previous .config> .config && make olddefconfig
scripts/kconfig/merge_config.sh -m .config <repo>/releases/kconfig/amd64/fragments/<name>.config
make olddefconfig
# every fragment symbol must survive; a mismatch means a missing dependency
grep '^CONFIG_' <fragment> | while read -r l; do grep -qx "$l" .config || echo "dropped: $l"; done
```

### dist-kernel fragments

Check a fragment against a gentoo-kernel version without catalyst (as a user):

```shell
DISTDIR=~/kbuild/distfiles PORTAGE_TMPDIR=~/kbuild/tmp USE=hardened \
  ebuild /var/db/repos/gentoo/sys-kernel/gentoo-kernel/gentoo-kernel-<ver>.ebuild clean configure
W=~/kbuild/tmp/portage/sys-kernel/gentoo-kernel-<ver>/work
mkdir -p ~/kbuild/check && cp $W/build/.config ~/kbuild/check/.config
cd $W/linux-* && scripts/kconfig/merge_config.sh -m -O ~/kbuild/check ~/kbuild/check/.config <fragment>
make O=~/kbuild/check olddefconfig
grep '^CONFIG_' <fragment> | while read -r l; do grep -qx "$l" ~/kbuild/check/.config || echo "dropped: $l"; done
```
