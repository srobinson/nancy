#!/usr/bin/env node

// attention-matters: Claude Code plugin installer
// Handles plugin lifecycle (init/uninstall/status) and delegates
// native commands (serve/query) to the Rust binary.

"use strict";

const { execSync, execFileSync, spawnSync } = require("child_process");
const path = require("path");
const fs = require("fs");
const os = require("os");

const MARKETPLACE_REPO = "srobinson/attention-matters";
const MARKETPLACE_NAME = "attention-matters";
const PLUGIN_NAME = "am-memory";

function log(msg) {
  console.log(`  ${msg}`);
}

function logStep(msg) {
  console.log(`\n  → ${msg}`);
}

function logSuccess(msg) {
  console.log(`  ✓ ${msg}`);
}

function logError(msg) {
  console.error(`  ✗ ${msg}`);
}

function commandExists(cmd) {
  const result = spawnSync("which", [cmd], { stdio: "ignore", timeout: 5000 });
  return result.status === 0;
}

function claudeVersion() {
  try {
    return execSync("claude --version", { encoding: "utf-8", timeout: 10000 }).trim();
  } catch {
    return null;
  }
}

function isMarketplaceAdded() {
  try {
    const out = execSync("claude plugin marketplace list", {
      encoding: "utf-8",
      timeout: 30000,
    });
    return out.includes(MARKETPLACE_NAME);
  } catch {
    return false;
  }
}

function isPluginInstalled() {
  try {
    const out = execSync("claude plugin list", { encoding: "utf-8", timeout: 30000 });
    return out.includes(PLUGIN_NAME);
  } catch {
    return false;
  }
}

function runClaude(...args) {
  const result = spawnSync("claude", args, { stdio: "inherit" });
  return result.status === 0;
}

function delegateToNative() {
  const binDir = path.join(__dirname, "..", "bin");
  const nativeBin = path.join(binDir, "am");
  const args = process.argv.slice(2);

  const candidates = [nativeBin, "am"].filter((c) => {
    if (c === "am") return true;
    try {
      return fs.existsSync(c);
    } catch {
      return false;
    }
  });

  for (const candidate of candidates) {
    try {
      execFileSync(candidate, args, { stdio: "inherit" });
      process.exit(0);
    } catch (err) {
      if (err.status != null) {
        process.exit(err.status);
      }
    }
  }

  console.error(
    "attention-matters: native binary not found.\n\n" +
      "The postinstall script may have failed. Install manually:\n" +
      "  cargo install am-cli\n"
  );
  process.exit(1);
}

function printUsage() {
  console.log(`
  attention-matters — Geometric memory for AI coding agents

  Plugin commands:
    npx attention-matters init         Install the am-memory plugin for Claude Code
    npx attention-matters uninstall    Remove the plugin and marketplace
    npx attention-matters status       Check installation status

  Native commands (passed to am binary):
    npx attention-matters serve        Start the MCP server
    npx attention-matters <cmd>        Any other am CLI command

  What happens on init:
    1. Detects Claude Code CLI
    2. Adds the attention-matters marketplace
    3. Installs the am-memory plugin (user scope)
    4. Plugin auto-activates on next Claude Code session

  Requirements:
    - Claude Code CLI (claude) must be installed
    - macOS or Linux
`);
}

function cmdInit() {
  console.log("\n  attention-matters — Plugin Installer\n");

  logStep("Checking for Claude Code...");

  if (!commandExists("claude")) {
    logError("Claude Code CLI not found.");
    log(
      "Install Claude Code first: https://docs.anthropic.com/en/docs/claude-code"
    );
    process.exit(1);
  }

  const version = claudeVersion();
  if (version) {
    logSuccess(`Claude Code detected (${version})`);
  }

  if (isPluginInstalled()) {
    logSuccess("am-memory plugin is already installed!");
    log("Start a new Claude Code session to use memory.");
    return;
  }

  logStep("Adding attention-matters marketplace...");
  if (isMarketplaceAdded()) {
    logSuccess("Marketplace already registered");
  } else {
    if (
      !runClaude("plugin", "marketplace", "add", MARKETPLACE_REPO)
    ) {
      logError("Failed to add marketplace.");
      log(
        "Try manually: claude plugin marketplace add srobinson/attention-matters"
      );
      process.exit(1);
    }
    logSuccess("Marketplace added");
  }

  logStep("Installing am-memory plugin...");
  if (
    !runClaude(
      "plugin",
      "install",
      `${PLUGIN_NAME}@${MARKETPLACE_NAME}`,
      "--scope",
      "user"
    )
  ) {
    logError("Failed to install plugin.");
    log("Try manually: claude plugin install am-memory@attention-matters");
    process.exit(1);
  }
  logSuccess("Plugin installed");

  console.log(`
  ✓ Memory system ready!

  Start a new Claude Code session — memory is automatic.
  No configuration needed.

  What happens now:
    - am MCP server starts automatically each session
    - SessionStart hook injects memory instructions
    - Claude queries, buffers, and strengthens memories
    - Use /memory for explicit memory operations

  Uninstall anytime:
    npx attention-matters uninstall
`);
}

function cmdUninstall() {
  console.log("\n  attention-matters — Plugin Uninstaller\n");

  if (!commandExists("claude")) {
    logError("Claude Code CLI not found. Nothing to uninstall.");
    process.exit(1);
  }

  logStep("Removing am-memory plugin...");
  if (isPluginInstalled()) {
    if (
      !runClaude(
        "plugin",
        "uninstall",
        `${PLUGIN_NAME}@${MARKETPLACE_NAME}`,
        "--scope",
        "user"
      )
    ) {
      logError("Failed to uninstall plugin.");
      process.exit(1);
    }
    logSuccess("Plugin removed");
  } else {
    log("Plugin not installed, skipping");
  }

  logStep("Removing marketplace...");
  if (isMarketplaceAdded()) {
    if (!runClaude("plugin", "marketplace", "remove", MARKETPLACE_NAME)) {
      logError("Failed to remove marketplace.");
      process.exit(1);
    }
    logSuccess("Marketplace removed");
  } else {
    log("Marketplace not registered, skipping");
  }

  console.log("\n  ✓ Uninstall complete. Memory data is preserved locally.\n");
}

function cmdStatus() {
  console.log("\n  attention-matters — Status\n");

  const hasClaude = commandExists("claude");
  log(`Claude Code: ${hasClaude ? "installed" : "not found"}`);

  if (!hasClaude) return;

  const version = claudeVersion();
  if (version) log(`Version: ${version}`);

  log(
    `Marketplace: ${isMarketplaceAdded() ? "registered" : "not registered"}`
  );
  log(`Plugin: ${isPluginInstalled() ? "installed" : "not installed"}`);
  log(`Platform: ${os.platform()}-${os.arch()}`);
  console.log();
}

const command = process.argv[2];

switch (command) {
  case "init":
    cmdInit();
    break;
  case "uninstall":
  case "remove":
    cmdUninstall();
    break;
  case "status":
    cmdStatus();
    break;
  case undefined:
  case "help":
  case "--help":
  case "-h":
    printUsage();
    break;
  default:
    // Unknown command — delegate to native binary (serve, query, etc.)
    delegateToNative();
    break;
}
