# kconfig changes

local oubliette changes

```shell
sed -i "s/\(CONFIG_USB_.*HCI.*\)=m/\1=y/" amd64-*.config
```
