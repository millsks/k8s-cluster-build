## Host: odin-k8s-cp01
```yaml
network:
  version: 2

  wifis:
    wlp6s0:
      dhcp4: true
      access-points:
        "WIFI-SSID":
          auth:
            key-management: "psk"
            password: "WIFI_PASSWORD"

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.10/24
```

## Host: huginn-k8s-wk01
```yaml
network:
  version: 2

  wifis:
    wlp6s0:
      dhcp4: true
      access-points:
        "WIFI-SSID":
          auth:
            key-management: "psk"
            password: "WIFI_PASSWORD"

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.20/24
```

## Host: muninn-k8s-wk02
```yaml
network:
  version: 2

  wifis:
    wlp6s0:
      dhcp4: true
      access-points:
        "WIFI-SSID":
          auth:
            key-management: "psk"
            password: "WIFI_PASSWORD"

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.21/24
```

## Host: geri-k8s-wk01
```yaml
network:
  version: 2

  wifis:
    wlp6s0:
      dhcp4: true
      access-points:
        "WIFI-SSID":
          auth:
            key-management: "psk"
            password: "WIFI_PASSWORD"

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.22/24
```

## Host: freki-k8s-wk02
```yaml
network:
  version: 2

  wifis:
    wlp6s0:
      dhcp4: true
      access-points:
        "WIFI-SSID":
          auth:
            key-management: "psk"
            password: "WIFI_PASSWORD"

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.23/24
```
