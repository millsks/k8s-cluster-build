## Host: odin-cp.cluster
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.10/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: huginn-wk.cluster
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.11/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: muninn-wk.cluster
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.12/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: geri-wk.cluster
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.13/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: freki-wk.cluster
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.14/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: heimdall.virtual
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.20/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: ymir.storage
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.5/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: niflheim.storage
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.30/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: mimir.net
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.40/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: gjallarhorn.net
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.41/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: valhalla.apps
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.42/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: idun.media
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.43/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: saga.docs
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.44/24
      nameservers:
        addresses:
          - 172.16.0.5
```

## Host: yggdrasil.iot
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
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  ethernets:
    enp5s0f0:
      dhcp4: no
      addresses:
        - 172.16.0.50/24
      nameservers:
        addresses:
          - 172.16.0.5
```
