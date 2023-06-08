# kconfig changes

local oubliette changes

```shell
sed -i "s/\(CONFIG_USB_.*HCI.*\)=m/\1=y/" *.config
sed -i 's/^#\ CONFIG_MLX4_EN\ is\ not\ set/CONFIG_MLX4_EN=m/' *.config
sed -i 's/^#\ CONFIG_MLX4_CORE_GEN2\ is\ not\ set/CONFIG_MLX4_CORE_GEN2=m/' *.config
```
