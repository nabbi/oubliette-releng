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
| `amd64-6.18.52-admincd.config` | `admincd-stage2.spec` | `amd64-6.6.30.config` (cloud baseline) + `fragments/admincd.config` |
| `amd64-7.2.8-framework.config` | `stage4-openrc-23-framework.spec` | previous framework config + `fragments/framework.config` |

`fragments/admincd.config` is generic hardware compatibility only (GOP console via
simpledrm, IOMMU interrupt remapping, newer Intel platforms, Wi-Fi 7, USB4). It deliberately has no native GPU drivers:
the ISO's pruned linux-firmware has no GPU blobs, and i915/xe/amdgpu evict the firmware
framebuffer before failing on missing firmware, leaving a blank screen. Anything
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
