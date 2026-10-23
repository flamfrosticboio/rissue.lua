// RIssue - Plugin for getting issues and merge requests from git providers
// Copyright (C) 2026  flamfrosticboio
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { execSync } = require("node:child_process");

// ---------------------------------------------------------------------------
// Constants (edit these)
// ---------------------------------------------------------------------------
const CONFIG = {
    // Directories
    luaDir: "lua",
    providersDir: "lua/rissue/providers",
    docsDir: "docs",
    tmpDir: ".tmp",

    // Commands
    languageServerCmd: (outDir) =>
        `lua-language-server --doc=lua --doc_out_path=${outDir}`,
    prettierCmd: (file) => `prettier --write "${file}"`,

    // lua-language-server output
    docJsonName: "doc.json",
    typePrefix: "rissue", // only entries whose name starts with this are documented

    // Providers: Lua can't be executed from Node, so name/version are
    // extracted from the source text with these regexes (group 1 = value).
    providerNameRe: /\bname\s*=\s*["']([^"']+)["']/,
    providerVersionRe: /\bversion\s*=\s*["']([^"']+)["']/,

    // Max line width before a field description wraps onto its own line
    fieldLineWidth: 80,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Recursively list all files under `dir`. */
function walk(dir) {
    const out = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) out.push(...walk(full));
        else if (entry.isFile()) out.push(full);
    }
    return out;
}

const read = (file) => fs.readFileSync(file, "utf8");
const formatDesc = (desc) => desc.trim().replace(/\n /g, "\n");

// ---------------------------------------------------------------------------
// READ: types (lua-language-server doc.json)
// ---------------------------------------------------------------------------

function parseFields(parentName, fields, buffer, parentSpec) {
    for (const field of fields) {
        const spec = {};
        const isFunction = field.view === "function";

        if (field.rawdesc) spec.description = formatDesc(field.rawdesc);

        const name = `${parentName}.${field.name}${isFunction ? "()" : ""}`;
        const lines = [`### ${name}`];

        if (spec.description) lines.push("", spec.description);

        if (isFunction) {
            const { args, returns } = field.extends ?? {};

            if (Array.isArray(args)) {
                lines.push("\n**Parameters:**\n");
                for (const arg of args) {
                    let line = `- \`${arg.name ?? "..."}\`: \`${arg.view}\``;
                    if (arg.rawdesc) line += ` -- ${arg.rawdesc}`;
                    lines.push(line);
                }
            }

            if (Array.isArray(returns)) {
                lines.push("\n**Returns:**\n");
                returns.forEach((ret, i) => {
                    let line = `- (${i + 1}) \`${ret.view}\``;
                    if (ret.rawdesc) line += ` -- ${ret.rawdesc}`;
                    lines.push(line);
                });
            }
        }

        spec.docs = lines.join("\n");
        buffer[name] = spec;

        if (!Array.isArray(parentSpec.fields)) {
            parentSpec.fields = [];
        }

        parentSpec.fields.push(name);
    }
}

function parseEntry(entry, buffer) {
    const name = entry.name;
    const spec = {};

    if (entry.desc) spec.description = formatDesc(entry.rawdesc);

    const lines = [`### \`${name}\``];

    // group defines by their type
    const defineType = {};
    for (const def of entry.defines ?? []) {
        if (!defineType[def.type]) {
            defineType[def.type] = [];
        }
        defineType[def.type].push(def);
    }

    const aliases = defineType["doc.alias"] ?? [];
    if (aliases.length > 0) {
        const joined = aliases.map((def) => `\`${def.view}\``).join(" | ");
        lines.push("", `Type: \`alias\` -- ${joined}`);
    } else if ((defineType["doc.class"] ?? []).length > 0) {
        lines.push("", "Type: `class`");
    }

    if (spec.description) lines.push("", spec.description);

    const entryFields = entry.fields ?? [];
    if (entry.type === "type" && entryFields.length > 0) {
        lines.push("");
        for (const field of entryFields) {
            if (field.visible !== "public" || field.type !== "doc.field") continue;

            let line = `- ${field.name}: \`${field.view}\``;
            if (field.rawdesc) {
                const header = ` -- ${field.rawdesc.replace(/\n/g, "\n  ")}`;
                line +=
                    line.length + header.length > CONFIG.fieldLineWidth
                        ? `\n${header}`
                        : header;
            }
            lines.push(line);
        }
    }

    spec.docs = lines.join("\n");

    if (entryFields.length > 0) parseFields(name, entryFields, buffer, spec);

    buffer[name] = spec;
}

function getTypes() {
    fs.mkdirSync(CONFIG.tmpDir, { recursive: true });
    execSync(CONFIG.languageServerCmd(CONFIG.tmpDir), { stdio: "inherit" });

    const spec = JSON.parse(read(path.join(CONFIG.tmpDir, CONFIG.docJsonName)));
    if (!Array.isArray(spec)) throw new Error("doc.json is not an array");

    const buffer = {};
    for (const item of spec) {
        if (
            typeof item.name === "string" &&
            item.name.startsWith(CONFIG.typePrefix)
        ) {
            parseEntry(item, buffer);
        }
    }
    return buffer;
}

// ---------------------------------------------------------------------------
// READ: constants (--- ### NAME ### --- blocks in Lua sources)
// ---------------------------------------------------------------------------

// Matches:
//   --- ### NAME ### ---
//   <contents>
//   --- ### NAME ### ---
const SOURCE_CONSTANT_RE =
    /(?:^|\n)---\s*###\s*([\w.]+)\s*###\s*---[ \t]*\r?\n([\s\S]*?)\r?\n---\s*###\s*\1\s*###\s*---[ \t]*(?=\r?\n|$)/g;

function getConstants() {
    const constants = {};
    for (const file of walk(CONFIG.luaDir)) {
        for (const match of read(file).matchAll(SOURCE_CONSTANT_RE)) {
            constants[match[1]] = match[2].trim();
        }
    }
    return constants;
}

// ---------------------------------------------------------------------------
// READ: provider versions
// ---------------------------------------------------------------------------

function getProviderVersions() {
    const versions = {};
    const visitedDirs = [];

    // shallower files first, init.lua first within a directory, so a module's
    // init.lua wins over the files inside it
    const depth = (f) => f.split(path.sep).length;
    const isInit = (f) => path.basename(f) === "init.lua";
    const files = walk(CONFIG.providersDir)
        .filter((f) => f.endsWith(".lua"))
        .sort(
            (a, b) =>
                depth(a) - depth(b) ||
                Number(isInit(b)) - Number(isInit(a)) ||
                a.localeCompare(b),
        );

    for (const file of files) {
        const dirname = path.dirname(file);
        const insideVisited = visitedDirs.some(
            (d) => dirname === d || dirname.startsWith(d + path.sep),
        );
        if (insideVisited) {
            console.log(`skipped $file`);
            continue;
        }

        const contents = read(file);
        const name = contents.match(CONFIG.providerNameRe)?.[1];
        const version = contents.match(CONFIG.providerVersionRe)?.[1];
        if (!name || !version) continue;

        versions[name] = version;
        if (isInit(file)) visitedDirs.push(dirname);
    }

    return versions;
}

// ---------------------------------------------------------------------------
// WRITE: replace marker blocks in docs
// ---------------------------------------------------------------------------

// <!-- &name@field --> ... <!-- &name@field -->
const TYPE_BLOCK_RE =
    /<!--\s*&([\w.()]+)@(\w+)\s*-->[\s\S]*?<!--\s*&\1@\2\s*-->/g;

function writeTypes(raw, types) {
    return raw.replace(TYPE_BLOCK_RE, (_, name, field) => {
        const doc = types[name]?.[field];
        if (doc === undefined) throw new Error(`unknown entry: ${name}@${field}`);

        const marker = `<!-- &${name}@${field} -->`;
        return `${marker}\n\n${doc}\n\n${marker}`;
    });
}

// <!-- *NAME --> ... <!-- *NAME -->
const CONSTANT_BLOCK_RE = /<!--\s*\*([\w.]+)\s*-->[\s\S]*?<!--\s*\*\1\s*-->/g;

function writeConstants(raw, constants) {
    return raw.replace(CONSTANT_BLOCK_RE, (_, name) => {
        const value = constants[name];
        if (value === undefined) throw new Error(`unknown constant: ${name}`);

        const marker = `<!-- *${name} -->`;
        return `${marker}\n\n\`\`\`lua\n${value}\n\`\`\`\n\n${marker}`;
    });
}

// <!-- @VERSION:name --> ... <!-- @VERSION:name -->
const VERSION_BLOCK_RE =
    /<!--\s*@VERSION:(\w+)\s*-->[\s\S]*?<!--\s*@VERSION:\1\s*-->/g;

function writeProviderVersions(raw, versions) {
    return raw.replace(VERSION_BLOCK_RE, (_, name) => {
        const version = versions[name];
        if (version === undefined) throw new Error(`unknown name: ${name}`);

        const marker = `<!-- @VERSION:${name} -->`;
        return `${marker}Version: ${version}${marker}`;
    });
}

function writeBlocks(raw, info) {
    raw = writeTypes(raw, info.types);
    raw = writeConstants(raw, info.constants);
    raw = writeProviderVersions(raw, info.versions);
    return raw;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
    const info = {
        types: getTypes(),
        constants: getConstants(),
        versions: getProviderVersions(),
    };

    for (const file of walk(CONFIG.docsDir)) {
        const before = read(file);
        fs.writeFileSync(file, writeBlocks(before, info));

        execSync(CONFIG.prettierCmd(file), { stdio: "inherit" });

        if (read(file) !== before) console.log(`Changes made on ${file}`);
    }
}

main();
