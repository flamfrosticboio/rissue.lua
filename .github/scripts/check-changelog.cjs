#!/usr/bin/env node
"use strict";

const { execFileSync } = require("node:child_process");

const { LABELS = "[]", BRANCH = "", BASE_SHA, HEAD_SHA } = process.env;

const OPT_OUT_LABEL = "no-changelog";
const TRIGGER_LABELS = ["feature", "bugfix", "bug"];
const TRIGGER_BRANCH = /^(feat|fix|bugfix|refactor|perf)\//;
const TRIGGER_SUBJECT = /^(feat|fix|refactor|perf)(\([^)]+\))?!?: /;
const BREAKING_FOOTER = /^BREAKING[ -]CHANGE/m;
const BREAKING_MARKER = /^[a-z]+(\([^)]+\))?!: /; // chore!, build!, etc.

// Changie fragments live here (changesDir + unreleasedDir in .changie.yaml).
const FRAGMENT_DIR = ".changes/unreleased/";
const FRAGMENT_EXT = /\.ya?ml$/;

// ---------------------------------------------------------------- helpers

function git(...args) {
  return execFileSync("git", args, { encoding: "utf8" });
}

function lines(text) {
  return text.split("\n").filter(Boolean);
}

function parseLabels(raw) {
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

// ----------------------------------------------------------------- checks

function requireShas() {
  if (!BASE_SHA || !HEAD_SHA) {
    fail("::error::BASE_SHA and HEAD_SHA must be set");
  }
}

function getCommits() {
  const range = `${BASE_SHA}..${HEAD_SHA}`;
  return {
    subjects: lines(git("log", "--no-merges", "--format=%s", range)),
    bodies: git("log", "--no-merges", "--format=%B", range),
  };
}

// Returns the list of reasons a changelog entry is required (empty if none).
function findTriggers(labels, commits) {
  const reasons = [];

  if (labels.some((l) => TRIGGER_LABELS.includes(l))) {
    reasons.push("label");
  }
  if (TRIGGER_BRANCH.test(BRANCH)) {
    reasons.push("branch");
  }
  if (commits.subjects.some((s) => TRIGGER_SUBJECT.test(s))) {
    reasons.push("commit");
  }
  if (BREAKING_FOOTER.test(commits.bodies)) {
    reasons.push("breaking-change");
  }
  if (commits.subjects.some((s) => BREAKING_MARKER.test(s))) {
    reasons.push("breaking-marker");
  }

  return reasons;
}

// Only newly added fragments count, so editing an old one does not pass.
function findAddedFragments() {
  return lines(
    git("diff", "--name-only", "--diff-filter=A", `${BASE_SHA}...${HEAD_SHA}`),
  ).filter((f) => f.startsWith(FRAGMENT_DIR) && FRAGMENT_EXT.test(f));
}

// ------------------------------------------------------------------- main

function main() {
  requireShas();

  const labels = parseLabels(LABELS);

  if (labels.includes(OPT_OUT_LABEL)) {
    console.log(`${OPT_OUT_LABEL} label set, skipping.`);
    return;
  }

  const reasons = findTriggers(labels, getCommits());
  if (reasons.length === 0) {
    console.log("No changelog required.");
    return;
  }

  console.log(`Changelog required (trigger: ${reasons.join(" ")})`);

  const added = findAddedFragments();
  if (added.length === 0) {
    fail(
      `::error title=Check Changelog::No changie fragment added under ${FRAGMENT_DIR}. ` +
        `Run "mise run change" and commit the file, or add the ${OPT_OUT_LABEL} label.`,
    );
  }

  console.log(`Changie fragment found: ${added.join(", ")}`);
}

main();
