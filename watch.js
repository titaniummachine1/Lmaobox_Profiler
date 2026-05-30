import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const DEBOUNCE_MS = 500;
const WATCH_DIRS = ["Profiler", "examples"];
const WATCH_GO = path.join("timing_collector", "cmd");

let timer = null;
let running = false;
let pending = false;
let pendingLuaOnly = true;

function queuePendingRun(luaOnly) {
	pending = true;
	if (!luaOnly) {
		pendingLuaOnly = false;
	}
}

function runRapidDev(luaOnly = false) {
	if (running) {
		queuePendingRun(luaOnly);
		return;
	}
	running = true;
	pending = false;
	pendingLuaOnly = true;
	const args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/rapid-dev.ps1"];
	if (luaOnly) {
		args.push("-LuaOnly");
	}
	console.log(`\n[watch] rapid-dev${luaOnly ? " (lua only)" : ""}...\n`);
	const child = spawn("powershell", args, {
		cwd: process.cwd(),
		stdio: "inherit",
		shell: false,
	});
	child.on("close", (code) => {
		running = false;
		console.log(`[watch] Done (exit ${code ?? "?"}).\n`);
		if (pending) {
			const rerunLuaOnly = pendingLuaOnly;
			pending = false;
			pendingLuaOnly = true;
			schedule(rerunLuaOnly);
		}
	});
}

function schedule(luaOnly = false) {
	if (timer) {
		clearTimeout(timer);
	}
	timer = setTimeout(() => runRapidDev(luaOnly), DEBOUNCE_MS);
}

function watchDir(dir, luaOnly) {
	const abs = path.resolve(dir);
	if (!fs.existsSync(abs)) {
		return;
	}
	fs.watch(abs, { recursive: true }, (_event, filename) => {
		if (!filename) {
			return;
		}
		const name = String(filename);
		if (dir === "Profiler" || dir === "examples") {
			if (!name.endsWith(".lua")) {
				return;
			}
		} else if (!name.endsWith(".go")) {
			return;
		}
		console.log(`[watch] ${path.join(dir, name)}`);
		schedule(luaOnly);
	});
	console.log(`[watch] Watching ${abs}`);
}

console.log("[watch] Auto build + deploy + restart collector on save");
watchDir("Profiler", false);
watchDir("examples", true);
watchDir(WATCH_GO, false);
runRapidDev(false);
