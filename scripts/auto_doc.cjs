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

  typesFile: "docs/types.md",

  // Commands
  languageServerCmd: (outDir) =>
    `lua-language-server --doc=lua --doc_out_path=${outDir} --configpath scripts/.luarc.docs.json`,
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

const escapeHtml = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// Markdown doesn't render inside <summary>, so convert the basics to HTML
const inlineMd = (s) =>
  escapeHtml(s)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");

const indent = (text) =>
  text
    .split("\n")
    .map((l) => (l ? `  ${l}` : ""))
    .join("\n");

// ---------------------------------------------------------------------------
// READ: types (lua-language-server doc.json)
// ---------------------------------------------------------------------------

function buildTypes(types) {
  const result = [];
  for (const t of types) {
    switch (t.type) {
      case "doc.type.table": // look subject to change
        result.push(t.view);
        break;
      default:
        result.push(t.view);
    }
  }

  return result.join(" | ");
}

function intoFunctionRepr(field_extends) {
  const args = (field_extends.args ?? [])
    .map((a) => `${a.name ?? "..."}: ${a.view}`)
    .join(", ");

  const returns = (field_extends.returns ?? []).map((r) => r.view).join(", ");

  return [
    field_extends.deprecated === true && "(deprecated)",
    field_extends.type === "setmethod" && "(method)",
    field_extends.async === true && "(async)",
    `function(${args})${returns ? `: ${returns}` : ""}`,
  ]
    .filter(Boolean)
    .join(" ");
}

function getType(field) {
  if (field.extends) {
    if (
      field.type === "setmethod" ||
      (field.type === "setfield" && field.extends.type === "function")
    ) {
      return intoFunctionRepr(field.extends);
    }
    if (field.extends.types) {
      return buildTypes(field.extends.types);
    }
  }
  return field.view;
}

/** Turns the field into a documentation
 * @param {any} field
 *@returns {string?} contents
 */
function fieldIntoDocumentation(field) {
  const name = field.name;

  if (name.startsWith("_") || field.visible !== "public") {
    return;
  }

  const description = field.rawdesc && formatDesc(field.rawdesc);
  const is_multiline = /\n\s*\n|```|^\s*[-*] /m.test(description ?? "");

  const lines = [];

  if (!is_multiline) {
    lines.push(
      `- \`${name}\`: \`${getType(field)}\`${description ? ` — ${description}` : ""}`,
    );
  } else {
    const title = `${name}`;
    const type_text = getType(field);

    // split at the first blank line: [first paragraph, ...rest]
    const [first = "", ...rest_parts] = (description ?? "").split(/\n\s*\n/);
    const first_line = first.replace(/\s*\n\s*/g, " ").trim();
    const rest = rest_parts.join("\n\n").trim();

    const head = [
      `<code>${escapeHtml(title)}</code>`,
      type_text && `<code>${escapeHtml(type_text)}</code>`,
    ]
      .filter(Boolean)
      .join(": ");

    const summary = first_line ? `${head} – ${inlineMd(first_line)}` : head;

    if (rest) {
      lines.push("- <details>");
      lines.push(`  <summary>${summary}</summary>`);
      lines.push("");
      lines.push(indent(rest));
      lines.push("");
      lines.push("  </details>");
    } else {
      // nothing to collapse, so use a plain bullet
      lines.push(
        `- \`${title}\`${type_text ? `: \`${type_text}\`` : ""}${first_line ? ` – ${first_line}` : ""}`,
      );
    }
  }

  return lines.join("\n");
}

const OPEN = "([{<";
const CLOSE = ")]}>";

const norm = (s) => s.trim().replace(/^'(.*)'$/, '"$1"');

/**
 * Split on `sep` only at the top level: not inside (), [], {}, <> or quotes.
 * So `fun(a: 2|4)`, `table<string|integer, any>` and `"a|b"` stay intact.
 */
function splitTopLevel(str, sep = "|") {
  const parts = [];
  let depth = 0;
  let quote = null;
  let cur = "";

  for (let i = 0; i < str.length; i++) {
    const ch = str[i];

    if (quote) {
      cur += ch;
      if (ch === "\\") cur += str[++i] ?? "";
      else if (ch === quote) quote = null;
      continue;
    }

    if (ch === '"' || ch === "'") {
      quote = ch;
      cur += ch;
      continue;
    }

    if (OPEN.includes(ch)) depth++;
    else if (CLOSE.includes(ch)) depth = Math.max(0, depth - 1);

    if (ch === sep && depth === 0) {
      parts.push(cur.trim());
      cur = "";
      continue;
    }
    cur += ch;
  }

  if (cur.trim()) parts.push(cur.trim());
  return parts.filter(Boolean);
}

/** Split `value -- comment`, ignoring `--` inside quoted strings. */
function splitComment(line) {
  let quote = null;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (quote) {
      if (ch === "\\") i++;
      else if (ch === quote) quote = null;
      continue;
    }
    if (ch === '"' || ch === "'") quote = ch;
    else if (ch === "-" && line[i + 1] === "-") {
      return [line.slice(0, i).trim(), line.slice(i + 2).trim()];
    }
  }
  return [line.trim(), ""];
}

/** Parse the `| "value" -- desc` lines out of a rawdesc alias block. */
function parseAliasDesc(rawdesc = "") {
  const entries = [];
  for (const line of rawdesc.split("\n")) {
    const m = line.match(/^\s*\|(>?)\s*(.*)$/);
    if (!m) continue;
    const [value, desc] = splitComment(m[2]);
    if (value) entries.push({ value, desc, isDefault: m[1] === ">" });
  }
  return entries;
}

/**
 * Builds a markdown list of a union/enum type.
 * - rawdesc: gives every literal, in declaration order, plus their descriptions
 * - view:    gives non-literal members (e.g. `string`, `boolean`) that rawdesc lacks
 * Returns "" when the type is not a union (fewer than 2 members).
 */
function formatUnion(rawdesc, view, { sep = " — ", code = true } = {}) {
  const fromDesc = parseAliasDesc(rawdesc);
  const truncated = /\.\.\.\(\+\d+\)\s*$/.test(view ?? "");

  const fromView = splitTopLevel(view ?? "")
    .map((p) => p.replace(/\.\.\.\(\+\d+\)\s*$/, "").trim())
    .filter(Boolean);

  const seen = new Set(fromDesc.map((e) => norm(e.value)));
  const extras = fromView
    .filter((v) => !seen.has(norm(v)))
    .map((value) => ({ value, desc: "", isDefault: false }));

  const entries = [...extras, ...fromDesc];
  if (entries.length < 2) return "";

  const render = (e) => {
    const value = code ? `\`${e.value}\`` : e.value;
    const desc = [e.desc, e.isDefault && "(default)"].filter(Boolean).join(" ");
    return `* ${value}${desc ? sep + desc : ""}`;
  };

  const lines = entries.map(render);
  // view was cut off and rawdesc couldn't fill the gap
  if (truncated && fromDesc.length === 0) lines.push("* ...");
  return lines.join("\n");
}

/** Converts an entry into a documentation
 * @returns {string}
 */
function intoDocumentation(entry) {
  /** @type {string[]} */
  const lines = [];

  const first_definition = entry.defines[0];
  if (!first_definition) {
    console.warn(`Entry ${name} passed but without any definition`);
    return;
  }
  const name = entry.name;

  // usually the doc type is usually on the first entry. If there are multiple, we
  // can check if they have the same types. If not, we must the user about it.
  const entry_type = first_definition?.type;
  if (entry.defines.length > 0) {
    for (let i = 1; i < entry.defines.length; i++) {
      const definition = entry.defines[i];
      if (definition && definition.type !== entry_type) {
        console.warn(
          `Multiple defines detected with different types across files for ${name}`,
        );
        break;
      }
    }
  }

  lines.push(`### \`${name}\``);

  if (entry_type === "doc.alias") {
    lines.push("");
    const formatted = formatUnion(
      first_definition.rawdesc,
      first_definition.view,
    );
    lines.push(
      `\`alias\` ${formatted ? `\`union\` ` : ""}${formatted ? `\n${formatted}` : ` \`${first_definition.view}\``} `,
    );
  }

  if (entry.rawdesc) {
    lines.push("");
    lines.push(formatDesc(entry.rawdesc));
  }

  if (entry.fields.length > 0) {
    lines.push("");
    for (const field of entry.fields) {
      const res = fieldIntoDocumentation(field);
      if (res) {
        lines.push(res);
      }
    }
  }

  return lines.join("\n");
}

function parseEntry(entry, buffer) {
  const name = entry.name;
  const spec = {};
  const visibility = entry.defines[0]?.visible;

  if (name === "rissue.provider.Supports")
    if (name.startsWith("_") || (visibility && visibility !== "public")) {
      return;
    }

  if (entry.desc) spec.description = formatDesc(entry.rawdesc);

  spec.docs = intoDocumentation(entry);

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
      console.log(`skipped ${file}`);
      continue;
    }

    const contents = read(file);
    const name = contents.match(CONFIG.providerNameRe)?.[1];
    if (!name) continue;

    const block = contents.match(/version\s*=\s*\{([^}]*)\}/)?.[1];
    if (!block) throw new Error("version table not found");

    const field = (k) => {
      const v = block.match(new RegExp(`\\b${k}\\s*=\\s*(\\d+)`))?.[1];
      if (v === undefined) throw new Error(`missing ${k}`);
      return Number(v);
    };

    const major = field("major");
    const minor = field("minor");
    const patch = field("patch");
    versions[name] = `${major}.${minor}.${patch}`;

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

function writeAllTypes(info_types) {
  const lines = [];
  const headers = [];

  for (const [name, item] of Object.entries(info_types)) {
    const doc = item.docs;
    if (doc) {
      lines.push(doc);
      const slug = (s) =>
        s
          .toLowerCase()
          .replace(/[^\w\- ]/g, "")
          .replace(/ /g, "-");

      headers.push(`- [\`${name}\`](#${slug(name)})`);
    }
  }

  fs.writeFileSync(
    CONFIG.typesFile,
    `# Types File\nThis section contains all types that \`rissue\` uses. (autogenerated by code)\n\n## Table of Contents\n\n${headers.join("\n")}\n\n## Types\n\n${lines.join("\n")}\n`,
  );
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

  writeAllTypes(info.types);

  for (const file of walk(CONFIG.docsDir)) {
    const before = read(file);
    fs.writeFileSync(file, writeBlocks(before, info));

    execSync(CONFIG.prettierCmd(file), { stdio: "inherit" });

    if (read(file) !== before) console.log(`Changes made on ${file}`);
  }
}

main();
