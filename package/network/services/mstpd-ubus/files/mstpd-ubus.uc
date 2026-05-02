#!/usr/bin/ucode
'use strict';

import * as uloop from "uloop";
import * as libubus from "ubus";
import * as fs from "fs";

const MSTPCTL = "/sbin/mstpctl";

let ubus;
let bridge_cfg = {};
let enable_pending = {};

const ENABLE_RETRY_DELAY_MS = 1000;
const ENABLE_RETRY_MAX = 30;

function log(msg)
{
	system(["logger", "-t", "mstpd-ubus", msg]);
}

function run_mstpctl(...args)
{
	return system([MSTPCTL, ...args]);
}

function run_mstpctl_output(...args)
{
	let cmd = MSTPCTL;
	for (let i = 0; i < length(args); i++)
		cmd += " " + args[i];

	let proc = fs.popen(cmd);
	if (!proc)
		return null;
	let output = proc.read("all");
	proc.close();
	return output;
}

function bridge_exists(name)
{
	return system(["/sbin/ip", "link", "show", "dev", name]) == 0;
}

function parse_showbridge(output)
{
	if (!output)
		return null;

	let result = {
		stp_enabled: false,
		enabled: false,
		bridge_id: null,
		designated_root: null,
		regional_root: null,
		root_port: null,
		path_cost: 0,
		internal_path_cost: 0,
		max_age: 0,
		bridge_max_age: 0,
		forward_delay: 0,
		bridge_forward_delay: 0,
		tx_hold_count: 0,
		max_hops: 0,
		hello_time: 0,
		ageing_time: 0,
		force_protocol_version: null,
		time_since_topology_change: 0,
		topology_change_count: 0,
		topology_change: false,
		topology_change_port: null,
		last_topology_change_port: null,
		is_root: false,
		root_priority: 0,
	};

	let lines = split(output, "\n");
	for (let i = 0; i < length(lines); i++) {
		let line = trim(lines[i]);
		if (!line || index(line, "info") >= 0)
			continue;

		let t = split(line, /\s+/);
		if (length(t) < 2)
			continue;

		if (t[0] == "stp" && t[1] == "enabled" && length(t) >= 3)
			result.stp_enabled = (lc(t[2]) == "yes");
		else if (t[0] == "enabled" && length(t) >= 2)
			result.enabled = (lc(t[1]) == "yes");
		else if (t[0] == "bridge" && t[1] == "id" && length(t) >= 3)
			result.bridge_id = t[2];
		else if (t[0] == "designated" && t[1] == "root" && length(t) >= 3)
			result.designated_root = t[2];
		else if (t[0] == "regional" && t[1] == "root" && length(t) >= 3)
			result.regional_root = t[2];
		else if (t[0] == "root" && t[1] == "port" && length(t) >= 3 && t[2] != "None")
			result.root_port = t[2];
		else if (t[0] == "path" && t[1] == "cost" && length(t) >= 7) {
			result.path_cost = int(t[2]);
			result.internal_path_cost = int(t[6]);
		}
		else if (t[0] == "max" && t[1] == "age" && length(t) >= 7) {
			result.max_age = int(t[2]);
			result.bridge_max_age = int(t[6]);
		}
		else if (t[0] == "forward" && t[1] == "delay" && length(t) >= 7) {
			result.forward_delay = int(t[2]);
			result.bridge_forward_delay = int(t[6]);
		}
		else if (t[0] == "tx" && t[1] == "hold" && t[2] == "count" && length(t) >= 7) {
			result.tx_hold_count = int(t[3]);
			result.max_hops = int(t[6]);
		}
		else if (t[0] == "hello" && t[1] == "time" && length(t) >= 6) {
			result.hello_time = int(t[2]);
			result.ageing_time = int(t[5]);
		}
		else if (t[0] == "force" && t[1] == "protocol" && t[2] == "version" && length(t) >= 4)
			result.force_protocol_version = t[3];
		else if (t[0] == "time" && t[1] == "since" && t[2] == "topology" && t[3] == "change" && length(t) >= 5)
			result.time_since_topology_change = int(t[4]);
		else if (t[0] == "topology" && t[1] == "change" && t[2] == "count" && length(t) >= 4)
			result.topology_change_count = int(t[3]);
		else if (t[0] == "topology" && t[1] == "change" && length(t) == 3)
			result.topology_change = (lc(t[2]) == "yes");
		else if (t[0] == "topology" && t[1] == "change" && t[2] == "port" && length(t) >= 4 && t[3] != "None")
			result.topology_change_port = t[3];
		else if (t[0] == "last" && t[1] == "topology" && t[2] == "change" && t[3] == "port" && length(t) >= 5 && t[4] != "None")
			result.last_topology_change_port = t[4];
	}

	// Compute derived fields
	if (result.bridge_id && result.designated_root) {
		result.is_root = (result.bridge_id == result.designated_root);
		let root_parts = split(result.designated_root, ".");
		if (root_parts && root_parts[0])
			result.root_priority = int(root_parts[0]) * 4096;
	}

	return result;
}

function parse_showport_all(output, bridge_name)
{
	if (!output)
		return [];

	let ports = [];
	let lines = split(output, "\n");
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		line = trim(line);
		if (!line)
			continue;

		let t = split(line, /\s+/);
		if (!length(t))
			continue;

		let off = (t[0] == "*") ? 1 : 0;
		if (length(t) < (off + 3))
			continue;

		let port = t[off];
		let role = (length(t) >= (off + 7)) ? t[off + 6] : "-";
		let state = (length(t) >= (off + 3)) ? t[off + 2] : "-";

		if (role == "Root")
			role = "Root";
		else if (role == "Desg")
			role = "Designated";
		else if (role == "Altn")
			role = "Alternate";
		else if (role == "Disa")
			role = "Disabled";

		if (state == "forw")
			state = "Forwarding";
		else if (state == "disc")
			state = "Discarding";
		else if (state == "down")
			state = "Discarding";

		let detail = run_mstpctl_output("showportdetail", bridge_name, port);
		let enabled = false;
		let path_cost = 0;
		let port_id = null;
		let port_priority = 0;
		let oper_edge = false;
		let oper_p2p = false;

		if (detail) {
			let dlines = split(detail, "\n");
			for (let j = 0; j < length(dlines); j++) {
				let dl = trim(dlines[j]);
				if (!dl)
					continue;

				let dt = split(dl, /\s+/);
				if (length(dt) < 2)
					continue;

				if (dt[0] == "enabled" && length(dt) >= 2)
					enabled = (lc(dt[1]) == "yes");
				if (dt[0] == "enabled" && length(dt) >= 4)
					role = dt[3];
				else if (dt[0] == "port" && dt[1] == "id" && length(dt) >= 3) {
					let id_parts = split(dt[2], ".");
					let raw = dt[2];
					if (length(id_parts) >= 2) {
						raw = id_parts[0] + id_parts[1];
						port_priority = int(id_parts[0]) * 16;
					}
					port_id = raw;
					if (length(dt) >= 5)
						state = dt[4];
				}
				else if (dt[0] == "external" && dt[1] == "port" && dt[2] == "cost" && length(dt) >= 4)
					path_cost = int(dt[3]);
				else if (dt[0] == "oper" && dt[1] == "edge" && dt[2] == "port" && length(dt) >= 4)
					oper_edge = (lc(dt[3]) == "yes");
				else if (dt[0] == "point-to-point" && length(dt) >= 2)
					oper_p2p = (lc(dt[1]) == "yes");
			}
		}

		if (role == "Root")
			role = "Root";
		else if (role == "Designated" || role == "Desg")
			role = "Designated";
		else if (role == "Alternate" || role == "Altn")
			role = "Alternate";
		else if (role == "Disabled" || role == "Disa")
			role = "Disabled";

		if (lc(state) == "forwarding" || state == "forw")
			state = "Forwarding";
		else if (lc(state) == "discarding" || state == "disc" || state == "down")
			state = "Discarding";

		push(ports, {
			port,
			enabled,
			role,
			state,
			path_cost,
			port_id,
			port_priority,
			oper_edge,
			oper_p2p,
		});
	}

	return ports;
}

// TODO: It seems that netifd reports invalid numbers. So ignore it for now.
function cache_bridge_config(data)
{
	if (!data?.name)
		return false;

	let cfg = bridge_cfg[data.name] ?? {};

	if (data.proto != null)
		cfg.proto = lc(data.proto);
	if (data.forward_delay != null)
		cfg.forward_delay = int(data.forward_delay);
	if (data.hello_time != null)
		cfg.hello_time = int(data.hello_time);
	if (data.max_age != null)
		cfg.max_age = int(data.max_age);
	if (data.ageing_time != null)
		cfg.ageing_time = int(data.ageing_time);

	bridge_cfg[data.name] = cfg;
	return true;
}

function try_enable_bridge(name)
{
	if (!bridge_exists(name))
		return -1;
	return run_mstpctl("addbridge", name);
}

function schedule_enable_bridge(name, retries)
{
	if (!name)
		return;

	let state = enable_pending[name];
	if (state?.active)
		return;

	enable_pending[name] = {
		active: true,
		retries: retries ?? ENABLE_RETRY_MAX,
	};

	function attempt() {
		let cur = enable_pending[name];
		if (!cur?.active)
			return;

		let rc = try_enable_bridge(name);
		if (rc == 0) {
			log(`bridge ${name} enabled under mstpd`);
			delete enable_pending[name];
			return;
		}

		cur.retries--;
		if (cur.retries <= 0) {
			log(`addbridge failed for ${name}: rc=${rc}, giving up`);
			delete enable_pending[name];
			return;
		}

		uloop.timer(ENABLE_RETRY_DELAY_MS, attempt);
	}

	uloop.timer(0, attempt);
}

function ubus_add_bridge(req)
{
	if (!cache_bridge_config(req.args))
		return libubus.STATUS_INVALID_ARGUMENT;

	return 0;
}

function ubus_bridge_state(req)
{
	let data = req.args ?? {};
	let name = data.name;
	let enabled = data.enabled;

	if (!name || enabled == null)
		return libubus.STATUS_INVALID_ARGUMENT;

	if (!bridge_exists(name))
		return libubus.STATUS_NOT_FOUND;

	if (enabled) {
		if (!(name in bridge_cfg))
			return libubus.STATUS_NOT_FOUND;

		let rc = try_enable_bridge(name);
		if (rc != 0) {
			schedule_enable_bridge(name, ENABLE_RETRY_MAX);
			return libubus.STATUS_UNKNOWN_ERROR;
		}
		return 0;
	}

	run_mstpctl("delbridge", name);

	return 0;
}

function ubus_get_bridge_info(req)
{
	let data = req.args ?? {};
	let name = data.name;

	if (!name)
		return libubus.STATUS_INVALID_ARGUMENT;

	if (!bridge_exists(name))
		return libubus.STATUS_NOT_FOUND;

	let output = run_mstpctl_output("showbridge", name);
	if (!output)
		return libubus.STATUS_NOT_FOUND;

	try {
		let info = parse_showbridge(output);
		if (!info)
			return libubus.STATUS_UNKNOWN_ERROR;
		req.reply(info);
		return 0;
	} catch (e) {
		log(`parse_showbridge error: ${e}`);
		return libubus.STATUS_UNKNOWN_ERROR;
	}
}

function ubus_get_port_list(req)
{
	let data = req.args ?? {};
	let name = data.name;

	if (!name)
		return libubus.STATUS_INVALID_ARGUMENT;

	if (!bridge_exists(name))
		return libubus.STATUS_NOT_FOUND;

	let output = run_mstpctl_output("showport", name);
	if (!output)
		return libubus.STATUS_NOT_FOUND;

	try {
		let ports = parse_showport_all(output, name);
		req.reply({ name: name, ports: ports });
		return 0;
	} catch (e) {
		log(`parse_showport_all error: ${e}`);
		return libubus.STATUS_UNKNOWN_ERROR;
	}
}

let ustp_obj = {
	add_bridge: {
		args: {
			name: "",
			proto: "",
			forward_delay: 0,
			hello_time: 0,
			max_age: 0,
			ageing_time: 0,
		},
		call: ubus_add_bridge,
	},
	bridge_state: {
		args: {
			name: "",
			enabled: true,
		},
		call: ubus_bridge_state,
	},
	get_bridge_info: {
		args: {
			name: "",
		},
		call: ubus_get_bridge_info,
	},
	get_port_list: {
		args: {
			name: "",
		},
		call: ubus_get_port_list,
	},
};

function ex_handler(e)
{
	log(`exception: ${e}`);
	return libubus.STATUS_UNKNOWN_ERROR;
}

uloop.init();
libubus.guard(ex_handler);
ubus = libubus.connect();

if (!ubus) {
	log("failed to connect to ubus");
	exit(1);
}

let sub = ubus.subscriber((msg) => {
	if (msg?.type != "stp_init")
		return;
	let name = msg.data?.name;
	log(`stp_init notification for ${name}`);
	cache_bridge_config(msg.data);
	/* Defer enable_bridge so netifd's own stp_state toggle (false->true)
	 * completes before mstpd bridge takeover. */
	if (name)
		uloop.timer(500, () => schedule_enable_bridge(name, ENABLE_RETRY_MAX));
});

function netifd_subscribe()
{
	try {
		if (sub && ubus.list("network.device")) {
			sub.subscribe("network.device");
			/* Like upstream ustp: trigger netifd to send stp_init for all
			 * currently active bridges so we can cache their config and
			 * take over management. Deferred to ensure uloop is running. */
			uloop.timer(100, () => {
				try { ubus.call("network.device", "stp_init", {}); } catch(e) {}
			});
		}
	} catch (e) {
		// network.device may not exist yet; listener will retry on object add.
	}
}

let listener = ubus.listener("ubus.object.add", (event, msg) => {
	if (msg?.path == "network.device")
		netifd_subscribe();
});

let ustp = ubus.publish("ustp", ustp_obj);

log("ustp ubus wrapper started");
netifd_subscribe();

uloop.run();
log("ustp ubus wrapper exiting");
