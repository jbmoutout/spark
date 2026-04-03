#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const HOOKS_DIR = path.join(process.cwd(), '.claude', 'hooks');
const SETTINGS_FILE = path.join(process.cwd(), '.claude', 'settings.json');
const PKG_DIR = path.resolve(__dirname, '..');

const HOOKS = [
  { src: 'spark.sh', timeout: 5000, event: 'UserPromptSubmit' },
  { src: 'spark-precompact.sh', timeout: 3000, event: 'PreCompact' },
  { src: 'spark-stop.sh', timeout: 5000, event: 'Stop' },
];

function loadSettingsWithBackup(settingsFile) {
  if (!fs.existsSync(settingsFile)) {
    return {};
  }

  try {
    return JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
  } catch {
    const backup = `${settingsFile}.spark.bak`;
    fs.copyFileSync(settingsFile, backup);
    console.log(`  Backed up invalid ${path.relative(process.cwd(), settingsFile)} to ${path.relative(process.cwd(), backup)}`);
    return {};
  }
}

function remove() {
  let removed = 0;
  for (const hook of HOOKS) {
    const dest = path.join(HOOKS_DIR, hook.src);
    if (fs.existsSync(dest)) {
      fs.unlinkSync(dest);
      removed++;
    }
  }

  if (fs.existsSync(SETTINGS_FILE)) {
    try {
      const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
      const hooks = settings.hooks || {};
      for (const event of Object.keys(hooks)) {
        for (const matcher of hooks[event]) {
          if (matcher.hooks) {
            matcher.hooks = matcher.hooks.filter(h => !h.command.includes('spark'));
          }
        }
        // Remove empty matchers
        hooks[event] = hooks[event].filter(m => m.hooks && m.hooks.length > 0);
        if (hooks[event].length === 0) delete hooks[event];
      }
      fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + '\n');
    } catch {}
  }

  console.log(`⚡ Spark removed. (${removed} hooks deleted)`);
}

function install() {
  console.log('⚡ Installing Spark...');

  // Create hooks dir
  fs.mkdirSync(HOOKS_DIR, { recursive: true });

  // Copy hook scripts
  for (const hook of HOOKS) {
    const src = path.join(PKG_DIR, hook.src);
    const dest = path.join(HOOKS_DIR, hook.src);
    fs.copyFileSync(src, dest);
    fs.chmodSync(dest, 0o755);
  }

  // Create or update settings.json
  const settings = loadSettingsWithBackup(SETTINGS_FILE);

  const hooks = settings.hooks = settings.hooks || {};

  for (const hook of HOOKS) {
    const event = hook.event;
    const entry = {
      type: 'command',
      command: `"$CLAUDE_PROJECT_DIR"/.claude/hooks/${hook.src}`,
      timeout: hook.timeout,
    };

    hooks[event] = hooks[event] || [];

    // Check if already registered
    const already = hooks[event].some(m =>
      (m.hooks || []).some(h => h.command.includes(hook.src))
    );

    if (!already) {
      if (hooks[event].length > 0 && hooks[event][0].hooks) {
        hooks[event][0].hooks.push(entry);
      } else {
        hooks[event].push({ matcher: '.*', hooks: [entry] });
      }
    }
  }

  fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + '\n');

  console.log('  Hooks installed to .claude/hooks/');
  console.log('  Settings updated in .claude/settings.json');
  console.log('');
  console.log('⚡ Spark installed. Start a Claude Code session to see the HUD.');
}

// CLI
const arg = process.argv[2];
if (arg === '--remove' || arg === 'remove' || arg === 'uninstall') {
  remove();
} else if (arg === '--help' || arg === '-h') {
  console.log('⚡ Spark — A HUD for Claude Code sessions');
  console.log('');
  console.log('Usage:');
  console.log('  npx spark-hud           Install Spark in current project');
  console.log('  npx spark-hud --remove  Remove Spark from current project');
} else {
  install();
}
