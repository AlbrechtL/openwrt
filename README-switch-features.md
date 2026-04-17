# Switch Features

Device: Zyxel GS1900-8 (Realtek RTL8380M SoC)
Kernel: Linux 6.18 with DSA (Distributed Switch Architecture)
Interfaces: `lan1` – `lan8` (DSA slave ports)

---

## Port Mirroring

Port mirroring copies all traffic from a source port to a monitor port, enabling passive traffic analysis without disrupting normal forwarding.

Both **ingress** (incoming) and **egress** (outgoing) traffic are mirrored and offloaded to hardware (`in_hw`).

### Prerequisites

Install `tc` (only needed once — does not persist across reboots unless added to a startup script):

```sh
apk add tc
```

### Configure Mirroring (port 2 → port 8)

Mirror all traffic on `lan2` to `lan8`:

```sh
tc qdisc add dev lan2 clsact
tc filter add dev lan2 ingress matchall action mirred egress mirror dev lan8
tc filter add dev lan2 egress  matchall action mirred egress mirror dev lan8
```

Verify (both rules should show `in_hw`):

```sh
tc -s filter show dev lan2 ingress
tc -s filter show dev lan2 egress
```

### Remove Mirroring

```sh
tc qdisc del dev lan2 clsact
```

This removes both ingress and egress filters in one step.

### Notes

- Replace `lan2` / `lan8` with any `lanN` interface to mirror different ports.
- Only one mirror destination per port is supported by the RTL83xx hardware.
- The `clsact` qdisc supports both ingress and egress filtering; the older `ingress` qdisc only covers incoming traffic.
- Configuration is not persistent — add the commands to `/etc/rc.local` or a procd init script to restore after reboot.

---

## UCI Support

Port mirroring can also be configured persistently through `/etc/config/port-mirror`.

Example UCI section:

```uci
config mirror 'lan2_to_lan8'
	option enabled '1'
	option source 'lan2'
	option target 'lan8'
	option ingress '1'
	option egress '1'
```

Equivalent UCI commands:

```sh
uci set port-mirror.lan2_to_lan8=mirror
uci set port-mirror.lan2_to_lan8.enabled='1'
uci set port-mirror.lan2_to_lan8.source='lan2'
uci set port-mirror.lan2_to_lan8.target='lan8'
uci set port-mirror.lan2_to_lan8.ingress='1'
uci set port-mirror.lan2_to_lan8.egress='1'
uci commit port-mirror
/etc/init.d/port-mirror reload
```

Disable the rule without deleting it:

```sh
uci set port-mirror.lan2_to_lan8.enabled='0'
uci commit port-mirror
/etc/init.d/port-mirror reload
```

Remove the rule completely:

```sh
uci delete port-mirror.lan2_to_lan8
uci commit port-mirror
/etc/init.d/port-mirror reload
```

Verify that the hardware offload is active:

```sh
tc -s filter show dev lan2 ingress
tc -s filter show dev lan2 egress
```

Both configured directions should report `in_hw`.
