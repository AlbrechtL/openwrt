# DISCLAIMER

This README was initially generated with AI assistance Please verify all technical details against the source code and runtime
behavior before production use.

# mstpd-ubus

OpenWrt package that ships `mstpd` plus a ucode ubus compatibility wrapper
(`ustp` object) so netifd can manage STP through the same API used by `ustp`.

## What This Package Installs

| Component | Path | Purpose |
|---|---|---|
| `mstpd` | `/sbin/mstpd` | STP/RSTP/MSTP daemon |
| `mstpctl` | `/sbin/mstpctl` | Control CLI for `mstpd` |
| `mstpd-ubus.uc` | `/usr/libexec/mstpd-ubus.uc` | Exposes `ustp` ubus object |
| `bridge-stp` | `/sbin/bridge-stp` | Kernel userspace-STP helper entry point |
| `mstp_restart` | `/sbin/mstp_restart` | Compatibility alias to `bridge-stp` |
| helper scripts | `/lib/mstpctl-utils/*` | Support scripts used by mstpd tooling |
| config | `/etc/bridge-stp.conf` | bridge-stp configuration |

## Important Behavior

1. `bridge-stp` must exist for Linux bridge to enter userspace STP mode
   (`stp_state=2`).
2. `brctl show` may show STP as `yes`/`2` while `mstpctl showbridge` still says
   disabled if bridge handoff is incomplete.
3. The wrapper now retries `mstpctl addbridge` on startup to avoid boot-order
   races (netifd bridge ready vs mstpd readiness).

## ubus API

Inspect API:

```sh
ubus -v list ustp
```

Methods:

1. `ustp add_bridge` — cache bridge configuration
2. `ustp bridge_state` — enable/disable bridge management
3. `ustp get_bridge_info` — query root bridge information
4. `ustp get_port_list` — query STP port states and metrics

### `ustp add_bridge`

Caches bridge configuration payload for compatibility with netifd/ustp flow.

Parameters:

| Field | Type |
|---|---|
| `name` | string |
| `proto` | string |
| `forward_delay` | int |
| `hello_time` | int |
| `max_age` | int |
| `ageing_time` | int |

Example:

```sh
ubus call ustp add_bridge '{
  "name": "switch",
  "proto": "rstp",
  "forward_delay": 15,
  "hello_time": 2,
  "max_age": 20,
  "ageing_time": 300
}'
```

### `ustp bridge_state`

Enables or disables mstpd bridge management.

Parameters:

| Field | Type |
|---|---|
| `name` | string |
| `enabled` | bool |

Examples:

```sh
# Enable
ubus call ustp bridge_state '{"name":"switch","enabled":true}'

# Disable
ubus call ustp bridge_state '{"name":"switch","enabled":false}'
```

### `ustp get_bridge_info`

Query root bridge information from mstpd. Returns detailed bridge state including root priority, topology change info, and protocol version.

**Note:** Bridge must be tracked in `add_bridge` cache before this method can be called.

Parameters:

| Field | Type |
|---|---|
| `name` | string |

Example request:

```sh
ubus call ustp get_bridge_info '{"name":"switch"}'
```

Example response:

```json
{
	"stp_enabled": true,
	"enabled": true,
	"bridge_id": "8.000.50:E0:39:F4:CF:7A",
	"designated_root": "8.000.00:15:7E:1D:E6:58",
	"regional_root": "8.000.50:E0:39:F4:CF:7A",
	"root_port": "lan1",
	"is_root": false,
	"root_priority": 32768,
	"path_cost": 20000,
	"internal_path_cost": 0,
	"max_age": 20,
	"bridge_max_age": 20,
	"forward_delay": 15,
	"bridge_forward_delay": 15,
	"tx_hold_count": 6,
	"max_hops": 20,
	"hello_time": 2,
	"ageing_time": 300,
	"force_protocol_version": "rstp",
	"time_since_topology_change": 1367,
	"topology_change_count": 1,
	"topology_change": false,
	"topology_change_port": null,
	"last_topology_change_port": "lan1"
}
```

### `ustp get_port_list`

Query STP port information for a bridge. Returns array of all bridge member ports with their states, costs, and role information.

**Note:** Bridge must be tracked in `add_bridge` cache before this method can be called.

Parameters:

| Field | Type |
|---|---|
| `name` | string |

Example request:

```sh
ubus call ustp get_port_list '{"name":"switch"}'
```

Example response:

```json
{
	"name": "switch",
	"ports": [
		{
			"port": "lan1",
			"enabled": true,
			"role": "RootPort",
			"state": "Forwarding",
			"path_cost": 20000,
			"port_id": "8001",
			"port_priority": 128,
			"oper_edge": false,
			"oper_p2p": true
		},
		{
			"port": "lan2",
			"enabled": true,
			"role": "AlternatePort",
			"state": "Discarding",
			"path_cost": 20000,
			"port_id": "8002",
			"port_priority": 128,
			"oper_edge": false,
			"oper_p2p": true
		},
		{
			"port": "lan3",
			"enabled": true,
			"role": "DesignatedPort",
			"state": "Forwarding",
			"path_cost": 20000,
			"port_id": "8003",
			"port_priority": 128,
			"oper_edge": false,
			"oper_p2p": true
		}
	]
}
```

#### Port Field Reference

- `port` — interface name (e.g., `lan1`, `eth0`)
- `enabled` — whether port is in active STP mode
- `role` — current port role: `RootPort`, `DesignatedPort`, `AlternatePort`, `BackupPort`, or `DisabledPort`
- `state` — current port state: `Discarding`, `Learning`, or `Forwarding`
- `path_cost` — STP cost of this port (lower is preferred toward root)
- `port_id` — 16-bit hex identifier (priority in upper byte, port number in lower)
- `port_priority` — derived from upper byte of `port_id` (typically 128, 192, 256, etc.)
- `oper_edge` — edge port in operation (fast convergence if true)
- `oper_p2p` — point-to-point link in operation (full-duplex)



## Boot And Runtime Flow

1. `/etc/init.d/mstpd` starts both `mstpd` and `mstpd-ubus.uc`.
2. Wrapper publishes `ustp` ubus object.
3. Wrapper subscribes to `network.device` and triggers `stp_init` replay.
4. On `stp_init`, wrapper caches bridge data and schedules `addbridge`.
5. If `addbridge` fails early (race), wrapper retries until success or timeout.

## Verification Commands

```sh
# Kernel STP mode (expect STP enabled  = 2 for userspace STP)
brctl show switch

# mstpd bridge status (expect enabled yes / stp enabled yes)
mstpctl showbridge switch

# ubus object signature
ubus -v list ustp

# wrapper logs
logread -f | grep mstpd-ubus
```

## Service Commands

```sh
service mstpd start
service mstpd stop
service mstpd restart
service mstpd enable
```

