#!/usr/bin/env node
/*
 * allostatik init — places the allostatik/ template files into a project.
 *
 * Node port of init.sh. Template sourcing is fetch-first-with-fallback:
 * try the CURRENT templates from the GitHub repo's main branch, and if the
 * fetch fails (offline, blocked, no tar available) fall back to the copy
 * BUNDLED in this package at publish time. Fresh when online, always works
 * offline, and both paths place real files — never reconstructed ones.
 * Pass --offline (or set ALLOSTATIK_OFFLINE=1) to skip the fetch entirely.
 * Same guards, same verification, same next-steps as init.sh.
 *
 * Mechanical only, by design: this command puts REAL files in the RIGHT
 * place. The walkthrough that fills them stays in workflow.md's first-run
 * routine (greenfield) or its migrate routine (existing project) — run by
 * whatever AI surface you use. Automate the mechanical; gate the meaningful.
 *
 * Usage:
 *   npx allostatik init /path/to/your-project
 *   npx allostatik init .          (from inside the project)
 *
 * Exit codes (mirrors init.sh): 1 usage, 2 collision/refuse, 4 incomplete.
 */

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const VERSION = require(path.join(__dirname, '..', 'package.json')).version;
// Fallback: templates bundled with the package at build/publish time (see build.sh):
const BUNDLED_BOILERPLATE = path.join(__dirname, '..', 'templates', 'project-boilerplate');
// Preferred: current templates from the repo's main branch:
const REPO_TARBALL = 'https://github.com/allostatik/allostatik/archive/refs/heads/main.tar.gz';
const FETCH_TIMEOUT_MS = 8000;

/**
 * Try to fetch the current templates from GitHub main. Returns the path to a
 * project-boilerplate dir on success, or null on ANY failure (offline, HTTP
 * error, no system tar, unexpected layout) — the caller falls back to the
 * bundle. Never throws.
 */
async function fetchLatestBoilerplate(tmpRoot) {
  try {
    const res = await fetch(REPO_TARBALL, {
      redirect: 'follow',
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
    if (!res.ok) return null;
    const buf = Buffer.from(await res.arrayBuffer());
    const tarPath = path.join(tmpRoot, 'allostatik-main.tar.gz');
    fs.writeFileSync(tarPath, buf);
    const untar = spawnSync('tar', ['-xzf', tarPath, '-C', tmpRoot], { timeout: FETCH_TIMEOUT_MS });
    if (untar.status !== 0) return null;
    // Locate project-boilerplate inside the extracted tree:
    const extracted = fs
      .readdirSync(tmpRoot)
      .map((e) => path.join(tmpRoot, e, 'templates', 'project-boilerplate'))
      .find((p) => fs.existsSync(path.join(p, 'allostatik')));
    return extracted || null;
  } catch {
    return null;
  }
}

const CORE_FILES = [
  'project-instructions.md',
  'plan.md',
  'decisions.md',
  'observations.md',
  'vision.md',
  'workflow.md',
  'knowledge/resources.md',
  'knowledge/environment.md',
];

const EXISTING_PROBES = ['README.md', 'docs', '.cursorrules', 'PLAN.md', 'src'];

function fail(msg, code) {
  process.stderr.write(msg.endsWith('\n') ? msg : msg + '\n');
  process.exit(code);
}

function usage() {
  process.stdout.write(
    [
      `allostatik ${VERSION} — installer for Allostatik (github.com/allostatik/allostatik)`,
      '',
      'Usage:',
      '  allostatik init <path-to-your-project>   place the allostatik/ template files',
      '                                         (fetches current templates from GitHub,',
      '                                         falls back to the bundled copy; --offline',
      '                                         or ALLOSTATIK_OFFLINE=1 skips the fetch)',
      '  allostatik --version                     print version',
      '  allostatik --help                        this message',
      '',
      'Allostatik is not an app — it is a folder of canonical context files plus',
      'session routines your AI follows. `init` places the real template files;',
      'your first AI session walks you through filling them (workflow.md owns that).',
      '',
    ].join('\n')
  );
}

async function main() {
  const args = process.argv.slice(2).filter((a) => a !== '--offline');
  let offline =
    process.argv.includes('--offline') || process.env.ALLOSTATIK_OFFLINE === '1';
  if (!offline && process.env.ALLOSTAT_OFFLINE === '1') { // legacy name, accepted until 1.0
    offline = true;
    process.stderr.write('note: ALLOSTAT_OFFLINE is deprecated; use ALLOSTATIK_OFFLINE\n');
  }

  if (args.includes('--version') || args.includes('-v')) {
    process.stdout.write(VERSION + '\n');
    return;
  }
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    usage();
    process.exit(args.length === 0 ? 1 : 0);
  }
  if (args[0] !== 'init') {
    fail(`error: unknown command "${args[0]}" — did you mean: allostatik init <path>?`, 1);
  }

  const target = args[1];
  if (!target) fail('usage: allostatik init /path/to/your-project', 1);
  const targetAbs = path.resolve(target);
  if (!fs.existsSync(targetAbs) || !fs.statSync(targetAbs).isDirectory()) {
    fail(`error: ${target} is not a directory`, 1);
  }

  // --- Probe: a pre-rename install. allostat/ is the old-generation folder
  // name (renamed to allostatik/ at 0.3.0); scaffolding beside it would
  // orphan it silently. Refuse and point at the migration steps.
  if (fs.existsSync(path.join(targetAbs, 'allostat'))) {
    fail(
      [
        `STOP: ${target}/allostat exists — a pre-rename Allostat install (the folder is allostatik/ since 0.3.0).`,
        'Nothing was written. Migrate instead of re-scaffolding:',
        '  https://github.com/allostatik/allostatik#migrating-from-allostat',
      ].join('\n'),
      2
    );
  }

  // --- Guard: the collision case. If target/allostatik exists and looks like
  // the TOOL's repo (has templates/ or concepts.md), the adopter cloned the
  // tool into the project — the #1 observed setup mistake. Refuse loudly.
  const targetAllostatik = path.join(targetAbs, 'allostatik');
  if (fs.existsSync(targetAllostatik)) {
    const looksLikeToolRepo =
      fs.existsSync(path.join(targetAllostatik, 'templates')) ||
      fs.existsSync(path.join(targetAllostatik, 'concepts.md'));
    if (looksLikeToolRepo) {
      fail(
        [
          `STOP: ${target}/allostatik contains the Allostatik tool's own repo, not project files.`,
          "The allostatik/ folder inside a project is reserved for the project's canonical files.",
          'Move the tool\'s clone elsewhere (e.g. ~/allostatik-repo), then re-run.',
        ].join('\n'),
        2
      );
    }
    fail(
      [
        `STOP: ${target}/allostatik already exists — refusing to overwrite.`,
        'Looking to update an existing install? That is an upgrade, not a re-run:',
        "  https://github.com/allostatik/allostatik/blob/main/CHANGELOG.md  (then the README's Upgrading section)",
        'If this is a partial setup you want to redo, remove or rename it and re-run.',
      ].join('\n'),
      2
    );
  }

  // --- Source the real template files: current repo main if reachable,
  // else the copy bundled in this package. NEVER generate or reconstruct —
  // if neither real source is available, the install is broken; stop.
  let boilerplate = null;
  let templateNote;
  let tmpRoot = null;
  if (!offline) {
    tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'allostatik-'));
    boilerplate = await fetchLatestBoilerplate(tmpRoot);
  }
  if (boilerplate) {
    templateNote = 'templates: current main from github.com/allostatik/allostatik';
  } else if (fs.existsSync(path.join(BUNDLED_BOILERPLATE, 'allostatik'))) {
    boilerplate = BUNDLED_BOILERPLATE;
    templateNote = offline
      ? `templates: bundled with package v${VERSION} (--offline)`
      : `templates: bundled with package v${VERSION} (GitHub not reachable — still real files, possibly not the newest)`;
  } else {
    fail(
      [
        'error: could not fetch templates from GitHub and the bundled copy is missing.',
        'Do NOT let an AI reconstruct these files from documentation. Get the real',
        'files instead: reinstall the package, or use the curl fallback in the README',
        'at github.com/allostatik/allostatik.',
      ].join('\n'),
      3
    );
  }

  // --- Place files.
  fs.cpSync(path.join(boilerplate, 'allostatik'), targetAllostatik, { recursive: true });

  // CLAUDE.md: never overwrite an existing one — the managed block gets added
  // by hand (or by your AI, gated) per the template's own instructions.
  let claudeNote;
  const targetClaudeMd = path.join(targetAbs, 'CLAUDE.md');
  if (fs.existsSync(targetClaudeMd)) {
    fs.copyFileSync(
      path.join(boilerplate, 'CLAUDE.md'),
      path.join(targetAllostatik, 'CLAUDE.md.allostatik-block')
    );
    claudeNote =
      'existing CLAUDE.md left untouched — the Allostatik block to add is at allostatik/CLAUDE.md.allostatik-block';
  } else {
    fs.copyFileSync(path.join(boilerplate, 'CLAUDE.md'), targetClaudeMd);
    claudeNote = 'CLAUDE.md placed (Claude Code manifest; harmless on other surfaces)';
  }

  // AGENTS.md: same rule — never overwrite. Cursor and other AGENTS.md-reading
  // surfaces load it from the project root.
  let agentsNote;
  const targetAgentsMd = path.join(targetAbs, 'AGENTS.md');
  if (fs.existsSync(targetAgentsMd)) {
    fs.copyFileSync(
      path.join(boilerplate, 'AGENTS.md'),
      path.join(targetAllostatik, 'AGENTS.md.allostatik-block')
    );
    agentsNote =
      'existing AGENTS.md left untouched — the Allostatik block to add is at allostatik/AGENTS.md.allostatik-block';
  } else {
    fs.copyFileSync(path.join(boilerplate, 'AGENTS.md'), targetAgentsMd);
    agentsNote = 'AGENTS.md placed (Cursor and other AGENTS.md surfaces; harmless elsewhere)';
  }
  if (tmpRoot) {
    try { fs.rmSync(tmpRoot, { recursive: true, force: true }); } catch { /* best effort */ }
  }

  // --- Verify: every expected file landed.
  const missing = CORE_FILES.filter((f) => !fs.existsSync(path.join(targetAllostatik, f)));
  if (missing.length > 0) {
    fail(`error: placement incomplete, missing: ${missing.join(' ')}`, 4);
  }

  // --- Detect mode for the walkthrough handoff.
  const mode = EXISTING_PROBES.some((p) => fs.existsSync(path.join(targetAbs, p)))
    ? 'existing'
    : 'greenfield';

  // The pointer block — keep VERBATIM in sync with the README's "Point your
  // project at the files" block (the parity test checks all three installers
  // print it):
  const POINTER_BLOCK = [
    '     This is an Allostatik project. The canonical files in its `allostatik/`',
    '     folder — `project-instructions.md`, `workflow.md`, `plan.md`,',
    '     `decisions.md`, … — are the source of truth. At the start of a',
    '     session, read them, follow `workflow.md`, treat them as authoritative,',
    '     and flag anything stale rather than just following it. If they',
    "     aren't set up yet, help me set them up — github.com/allostatik/allostatik",
    '     is the reference.',
  ];
  const lines = [
    '',
    `allostatik/ placed in ${target}  (${claudeNote}; ${agentsNote})`,
    `  ${templateNote}`,
    '',
    'Next steps (the files take it from here):',
    '  1. Point your project at the files. Claude Code or Cursor? Skip this',
    '     step — the placed CLAUDE.md / AGENTS.md does it. Claude Desktop?',
    "     This step is yours: create a project for this work (if one doesn't",
    '     exist yet), then paste this block into its Project Instructions',
    '     field. Other surfaces: the project-level instructions slot.',
    '',
    '     ----- copy from here -----',
    ...POINTER_BLOCK,
    '     ----- copy to here -----',
    '',
    '  2. Using git? Commit the fresh install as its own commit before you',
    "     fill anything in (git init first if the folder isn't a repo yet) —",
    '     every later diff is then provably yours.',
  ];
  if (mode === 'existing') {
    lines.push(
      '  3. This looks like an EXISTING project. In your first session, Claude should',
      "     follow workflow.md's 'First run — existing project (migrate)' routine:",
      '     it walks YOU through each file, drawing on your current docs — it must',
      '     not silently bulk-fill them. If it starts writing files without you,',
      '     stop it and point it at that routine.'
    );
  } else {
    lines.push(
      "  3. Fresh project: your first session runs workflow.md's first-run setup —",
      '     Claude proposes, you keep/change/drop, file by file.'
    );
  }
  lines.push("  4. Confirm it took: new conversation in the project, ask 'where do things stand?'", '');
  process.stdout.write(lines.join('\n'));
}

main().catch((err) => {
  process.stderr.write(`error: ${err && err.message ? err.message : err}\n`);
  process.exit(1);
});
