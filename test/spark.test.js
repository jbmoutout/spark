const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const repoRoot = path.resolve(__dirname, '..');

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'spark-test-'));
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    ...options,
  });

  if (result.error) {
    throw result.error;
  }

  return result;
}

function assertSuccess(result) {
  assert.equal(
    result.status,
    0,
    `expected success\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
}

function initGitRepo(dir) {
  assertSuccess(run('git', ['init', '-q'], { cwd: dir }));
  assertSuccess(run('git', ['config', 'user.email', 'spark@example.com'], { cwd: dir }));
  assertSuccess(run('git', ['config', 'user.name', 'Spark Test'], { cwd: dir }));
}

function commitAll(dir, message = 'init') {
  assertSuccess(run('git', ['add', '.'], { cwd: dir }));
  assertSuccess(run('git', ['commit', '-qm', message], { cwd: dir }));
}

function writeFile(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

function writeJson(filePath, value) {
  writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function runSparkHook(projectDir, extraEnv = {}, input = '') {
  const result = run('bash', [path.join(repoRoot, 'spark.sh')], {
    cwd: projectDir,
    env: {
      ...process.env,
      CLAUDE_PROJECT_DIR: projectDir,
      ...extraEnv,
    },
    input,
  });
  assertSuccess(result);
  const payload = JSON.parse(result.stdout);
  return payload.hookSpecificOutput.additionalContext;
}

function runStopHook(projectDir, payload, extraEnv = {}) {
  return run('bash', [path.join(repoRoot, 'spark-stop.sh')], {
    cwd: projectDir,
    env: {
      ...process.env,
      CLAUDE_PROJECT_DIR: projectDir,
      ...extraEnv,
    },
    input: JSON.stringify(payload),
  });
}

test('install.sh installs in a fresh directory using local hook files', () => {
  const projectDir = makeTempDir();
  const result = run('bash', [path.join(repoRoot, 'install.sh')], { cwd: projectDir });
  assertSuccess(result);

  const settings = readJson(path.join(projectDir, '.claude', 'settings.json'));
  const hooksDir = path.join(projectDir, '.claude', 'hooks');

  for (const hook of ['spark.sh', 'spark-precompact.sh', 'spark-stop.sh']) {
    const installed = path.join(hooksDir, hook);
    assert.equal(fs.existsSync(installed), true);
    assert.equal(
      fs.readFileSync(installed, 'utf8'),
      fs.readFileSync(path.join(repoRoot, hook), 'utf8')
    );
  }

  assert.equal(settings.hooks.UserPromptSubmit[0].hooks[0].command.includes('spark.sh'), true);
  assert.equal(settings.hooks.PreCompact[0].hooks[0].command.includes('spark-precompact.sh'), true);
  assert.equal(settings.hooks.Stop[0].hooks[0].command.includes('spark-stop.sh'), true);
});

test('install.sh backs up invalid settings and repairs hook configuration', () => {
  const projectDir = makeTempDir();
  writeFile(path.join(projectDir, '.claude', 'settings.json'), '{invalid json\n');

  const result = run('bash', [path.join(repoRoot, 'install.sh')], { cwd: projectDir });
  assertSuccess(result);

  assert.equal(
    fs.existsSync(path.join(projectDir, '.claude', 'settings.json.spark.bak')),
    true
  );

  const settings = readJson(path.join(projectDir, '.claude', 'settings.json'));
  assert.equal(Array.isArray(settings.hooks.UserPromptSubmit), true);
  assert.equal(Array.isArray(settings.hooks.PreCompact), true);
  assert.equal(Array.isArray(settings.hooks.Stop), true);
});

test('install.sh preserves unrelated hooks and does not duplicate Spark entries', () => {
  const projectDir = makeTempDir();
  writeJson(path.join(projectDir, '.claude', 'settings.json'), {
    hooks: {
      Stop: [
        {
          matcher: '.*',
          hooks: [{ type: 'command', command: 'echo keep-me', timeout: 1000 }],
        },
      ],
      Notification: [
        {
          matcher: '.*',
          hooks: [{ type: 'command', command: 'echo notify', timeout: 2000 }],
        },
      ],
    },
  });

  assertSuccess(run('bash', [path.join(repoRoot, 'install.sh')], { cwd: projectDir }));
  assertSuccess(run('bash', [path.join(repoRoot, 'install.sh')], { cwd: projectDir }));

  const settings = readJson(path.join(projectDir, '.claude', 'settings.json'));
  assert.equal(settings.hooks.Stop[0].hooks.some((hook) => hook.command === 'echo keep-me'), true);
  assert.equal(settings.hooks.Notification[0].hooks[0].command, 'echo notify');

  const sparkCounts = {
    UserPromptSubmit: settings.hooks.UserPromptSubmit[0].hooks.filter((hook) =>
      hook.command.includes('spark.sh')
    ).length,
    PreCompact: settings.hooks.PreCompact[0].hooks.filter((hook) =>
      hook.command.includes('spark-precompact.sh')
    ).length,
    Stop: settings.hooks.Stop.flatMap((matcher) => matcher.hooks).filter((hook) =>
      hook.command.includes('spark-stop.sh')
    ).length,
  };

  assert.deepEqual(sparkCounts, {
    UserPromptSubmit: 1,
    PreCompact: 1,
    Stop: 1,
  });
});

test('spark.sh reports files_touched in an unborn repo', () => {
  const projectDir = makeTempDir();
  initGitRepo(projectDir);
  writeFile(path.join(projectDir, '.gitignore'), '.spark/\n');
  writeFile(path.join(projectDir, 'notes.txt'), 'todo later\n');
  writeJson(path.join(projectDir, '.spark', 'state.json'), {
    session_start: '2026-04-03T00:00:00Z',
    prompt_count: 1,
  });

  const context = runSparkHook(projectDir);
  assert.match(context, /UNTRUSTED files_touched: [0-9]+ files/);
  assert.doesNotMatch(context, /files_touched: ,/);
});

test('spark.sh handles leading-dash filenames in TODO and secret scanners', () => {
  const projectDir = makeTempDir();
  initGitRepo(projectDir);
  writeFile(path.join(projectDir, '.gitignore'), '.spark/\n');
  writeJson(path.join(projectDir, '.spark', 'state.json'), {
    session_start: '2026-04-03T00:00:00Z',
    prompt_count: 1,
  });
  writeFile(path.join(projectDir, '--help'), 'token=abc\nTODO: investigate\n');
  assertSuccess(run('git', ['add', '--', '--help', '.gitignore'], { cwd: projectDir }));

  const context = runSparkHook(projectDir);
  assert.match(context, /SECRETS:1/);
  assert.match(context, /todos: 1 TODOs/);
});

test('spark.sh renders clean branch labels in minimal theme', () => {
  const projectDir = makeTempDir();
  initGitRepo(projectDir);
  writeFile(path.join(projectDir, '.gitignore'), '.spark/\n');
  writeFile(path.join(projectDir, 'tracked.txt'), 'tracked\n');
  commitAll(projectDir);
  assertSuccess(run('git', ['checkout', '-qb', 'demo-branch'], { cwd: projectDir }));
  writeJson(path.join(projectDir, '.spark', 'state.json'), {
    session_start: '2026-04-03T00:00:00Z',
    prompt_count: 1,
  });
  writeJson(path.join(projectDir, '.spark', 'config.json'), {
    theme: 'minimal',
    widgets: {
      branch: 'display',
      tokens: 'display',
      session_clock: 'display',
    },
  });

  const context = runSparkHook(projectDir);
  assert.match(context, /⚡ demo-branch/);
  assert.doesNotMatch(context, /git:demo-branch/);
});

test('spark-stop.sh records transcript token totals for normal input', () => {
  const projectDir = makeTempDir();
  writeJson(path.join(projectDir, '.spark', 'state.json'), {
    session_start: '2026-04-03T00:00:00Z',
    prompt_count: 1,
  });
  const transcriptPath = path.join(projectDir, 'transcript.jsonl');
  writeFile(
    transcriptPath,
    [
      JSON.stringify({ usage: { input_tokens: 10, output_tokens: 4, cache_read_tokens: 3 } }),
      JSON.stringify({
        message: {
          usage: {
            input_tokens: 5,
            output_tokens: 2,
            cache_creation_tokens: 7,
          },
        },
      }),
      '',
    ].join('\n')
  );

  const result = runStopHook(projectDir, { transcript_path: transcriptPath });
  assertSuccess(result);

  const state = readJson(path.join(projectDir, '.spark', 'state.json'));
  assert.equal(state.tokens_input, 15);
  assert.equal(state.tokens_output, 6);
  assert.equal(state.tokens_cache_read, 3);
  assert.equal(state.tokens_cache_create, 7);
});

test('spark-stop.sh ignores oversized transcript files', () => {
  const projectDir = makeTempDir();
  writeJson(path.join(projectDir, '.spark', 'state.json'), {
    session_start: '2026-04-03T00:00:00Z',
    prompt_count: 1,
  });
  const transcriptPath = path.join(projectDir, 'transcript.jsonl');
  writeFile(transcriptPath, '0123456789');

  const result = runStopHook(
    projectDir,
    { transcript_path: transcriptPath },
    { SPARK_MAX_TRANSCRIPT_BYTES: '4' }
  );
  assertSuccess(result);

  const state = readJson(path.join(projectDir, '.spark', 'state.json'));
  assert.equal(state.tokens_input, undefined);
  assert.equal(state.tokens_output, undefined);
});

test('bin/cli.js backs up invalid settings and installs hooks', () => {
  const projectDir = makeTempDir();
  writeFile(path.join(projectDir, '.claude', 'settings.json'), '{invalid json\n');

  const result = run('node', [path.join(repoRoot, 'bin', 'cli.js')], { cwd: projectDir });
  assertSuccess(result);

  assert.equal(
    fs.existsSync(path.join(projectDir, '.claude', 'settings.json.spark.bak')),
    true
  );
  assert.equal(fs.existsSync(path.join(projectDir, '.claude', 'hooks', 'spark.sh')), true);
});
