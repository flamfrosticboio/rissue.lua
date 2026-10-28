// Complicated script, but with the help of claude

let failed = false;

const { spawnSync } = require("node:child_process");
const { basename } = require("node:path");

const BASE = process.env.BASE_SHA;
const HEAD = process.env.HEAD_SHA;
const ROOT = "lua/rissue/providers";

function git(...args) {
    const r = spawnSync("git", args, { encoding: "utf8" });
    return r.status === 0 ? r.stdout : "";
}

function parseVersion(src) {
    const block = src.match(/version\s*=\s*\{([^}]*)\}/);
    if (!block) return null;
    const get = (k) => block[1].match(new RegExp(`\\b${k}\\s*=\\s*(\\d+)`))?.[1];
    const v = [get("major"), get("minor"), get("patch")].map(Number);
    return v.some(Number.isNaN) ? null : v;
}

function shouldBump(path) {
    const log = git("log", "--format=%s%n%b", `${BASE}..${HEAD}`, "--", path);
    if (/^(fix|perf|feat)/m.test(log)) return true;
    if (/^\w+(\(.+\))?!:|BREAKING CHANGE/m.test(log)) return true;
    return false;
}

function isVersionEqual(a, b) {
    return a[0] === b[0] && a[1] === b[1] && a[2] === b[2];
}

for (const line of git("ls-tree", HEAD, `${ROOT}/`)
    .split("\n")
    .filter(Boolean)) {
    const [meta, path] = line.split("\t");
    const isDir = meta.split(" ")[1] === "tree";
    const verFile = isDir ? `${path}/init.lua` : path;

    // Skip checking bump when there is no commits affecting this provider module
    if (!git("diff", "--name-only", BASE, HEAD, "--", path).trim()) continue;

    const baseSrc = git("show", `${BASE}:${verFile}`);
    if (!baseSrc) continue; // new entry

    // skipping would be fine when its chore
    // (like renaming internal names to make reading easier)
    if (shouldBump(path) === false) continue;

    const provider_name = basename(path, ".lua");
    const baseV = parseVersion(baseSrc);
    const headV = parseVersion(git("show", `${HEAD}:${verFile}`));

    if (baseV !== null && headV !== null) {
        if (isVersionEqual(baseV, headV)) {
            console.log(
                `${provider_name}: version not bumped (still at ${headV[0]}.${headV[1]}.${headV[2]})`,
            );
            failed = true;
        }
    } else if (!baseV) {
        console.log(`${path}: could not parse version (base is broken)`);
        failed = true;
    } else if (!headV) {
        console.log(`${path}: could not parse version (head is broken)`);
        failed = true;
    } else {
        console.log(`${path}: could not parse version (unknown error)`);
        failed = true;
    }
}

process.exit(failed ? 1 : 0);
