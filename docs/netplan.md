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
        - 172.16.0.11/24
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
        - 172.16.0.12/24
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
        - 172.16.0.13/24
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
        - 172.16.0.14/24
```

## Host: heimdall-virtual
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

## Host: ymir-storage
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
        - 172.16.0.5/24
```

## Host: niflheim-storage
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
        - 172.16.0.30/24
```

## Host: mimir-net
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
        - 172.16.0.40/24
```

## Host: gjallarhorn-net
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
        - 172.16.0.41/24
```

## Host: valhalla-apps
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
        - 172.16.0.42/24
```

## Host: idun-media
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
        - 172.16.0.43/24
```

## Host: saga-docs
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
        - 172.16.0.44/24
```

## Host: yggdrasil-iot
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
        - 172.16.0.50/24
```
