# Admin ISO

`releases/specs/amd64/hardened/admincd-stage1.spec` and `admincd-stage2.spec`, in
`SET_hardened_openrc_23_splitusr_OPTIONAL_SPECS` in `tools/catalyst-auto-amd64.conf`. Feature list
in the top-level `README.md`.

## Kernel and ZFS

OpenZFS is required on the ISO: `boot/kernel/gentoo/packages` builds `sys-fs/zfs` (and
`net-wireless/broadcom-sta`) against the ISO kernel. The kernel can only be as new as the newest
Linux that `sys-fs/zfs` supports.

Current state (2026-11-22):

| | |
|---|---|
| ISO kernel | `=sys-kernel/gentoo-sources-7.2.15`, config `releases/kconfig/amd64/amd64-7.2.8-admincd.config` |
| `sys-fs/zfs` | 2.4.4, `MODULES_KERNEL_MAX=7.2` |
| 7.2.15 source | `::oubliette` (`sys-kernel/gentoo-sources`); `::gentoo` dropped 7.2 at EOL on 2026-11-07 |
| genpatches-7.2-16 | gone from dev.gentoo.org, still on distfiles.gentoo.org; keep a copy in the build host's distfiles |

7.2 is EOL upstream: no further security fixes. Treat the pin as temporary. The other images are
not held back: the server stage4 builds the newest keyworded gentoo-sources (7.3), and the
Framework stage4s have no zfs and build `gentoo-kernel` 7.3 on the host.

### Why zfs-2.4.4 fails on 7.3

The ebuild reads `Linux-Maximum` from upstream `META` and dies in `pkg_setup`:

```
 * ERROR: sys-fs/zfs-2.4.4::gentoo failed (setup phase):
CatalystError: cmd(['/usr/share/catalyst/targets/livecd-stage2/controller.sh', 'kernel', 'gentoo']) exited 1
```

`ZFS_KERNEL_COMPAT_OVERRIDE=7.3` gets past that check but not the build: configure then stops at
the `iops->create()` probe. Linux 7.3 changed four interfaces the 2.4.4 SPL/ZPL glue uses
(<https://github.com/openzfs/zfs/issues/19032>):

- `inode_operations.create` dropped its flags argument (torvalds/linux `b2f1e6301efa`); on 2.4.x
  the backport must still define `HAVE_IOPS_CREATE_IDMAP`, or it builds with the wrong idmap types
- `bvec_iter.bi_bvec_done` renamed to `bi_offset`
- kernel threads no longer see the host filesystem by default
- `static_cpu_has()` replaced by `cpu_feature_enabled()` (SIMD checksum and RAID-Z paths)

Do not force the override on this ISO.

### Upstream status

Checked 2026-11-22. No release date announced.

- master: 7.3 support merged 2026-10-26 (<https://github.com/openzfs/zfs/pull/19553> and related)
- 2.4.x backport: <https://github.com/openzfs/zfs/pull/19838> against `zfs-2.4.5-staging`, open,
  Priority: High, code review needed
- 2.4.5: the release maintainer is preparing it and has pulled the 7.3 commits (2026-11-11 comment
  on #19838)
- Ubuntu 26.10 already ships 2.4.4 with the same set as distro patches (`zfs-linux 2.4.4-1ubuntu4`)
- Gentoo: no 7.3-capable zfs yet

### Moving the ISO to 7.3

Once `::gentoo` has a `sys-fs/zfs` with `MODULES_KERNEL_MAX` of 7.3 or later:

1. `admincd-stage2.spec`: `boot/kernel/gentoo/sources: gentoo-sources` and
   `boot/kernel/gentoo/config: .../amd64-7.3.5-admincd.config` (kept in the tree for this), drop
   the pin comment
2. `releases/portage/isos/package.accept_keywords/gentoo-sources`: drop the 7.2 entry
3. `releases/kconfig/amd64/README.md`: move `admincd-stage2.spec` back to the 7.3.5 row; remove
   `amd64-7.2.8-admincd.config`
4. `::oubliette`: remove `sys-kernel/gentoo-sources`
5. update this file and the Admin ISO section of `FRAMEWORK-WORKSTATION.md`

If 2.4.5 is slow, the fallback is to carry the five #19838 commits as a 2.4.4 patch in
`::oubliette` (what Ubuntu does) and leave EOL 7.2 sooner.
