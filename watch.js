import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const DEBOUNCE_MS = 400;
const WATCH_DIRS = ["Profiler", "examples"];

let timer = null;
let running = false;

function runBundleDeploy() {
	if (running) {
		return;
	}
	running = true;
	console.log("\n[watch] Running bundle-and-deploy...\n");
	const child = spawn(process.execPath, ["bundle-and-deploy.js"], {
		cwd: process.cwd(),
		stdio: "inherit",
		shell: false,
	});
	child.on("close", (code) => {
		running = false;
		console.log(`[watch] Done (exit ${code ?? "?"}). Watching for changes...\n`);
	});
}

function schedule() {
	if (timer) {
		clearTimeout(timer);
	}
	timer = setTimeout(runBundleDeploy, DEBOUNCE_MS);
}

function watchDir(dir) {
	const abs = path.resolve(dir);
	if (!fs.existsSync(abs)) {
		return;
	}
	fs.watch(abs, { recursive: true }, (_event, filename) => {
		if (!filename || !String(filename).endsWith(".lua")) {
			return;
		}
		console.log(`[watch] ${path.join(dir, filename)}`);
		schedule();
	});
	console.log(`[watch] Watching ${abs}`);
}

console.log("[watch] Profiler auto bundle+deploy — save any .lua under Profiler/ or examples/");
for (const dir of WATCH_DIRS) {
	watchDir(dir);
}
runBundleDeploy();
