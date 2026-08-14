'use strict';

const { spawnSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

const ROOT = path.join(__dirname, '..');
const RUNTIME_DIR = path.join(ROOT, 'runtime');
const NODE_RUNTIME_DIR = path.join(ROOT, 'node-runtime');
const NODE_BINARY = path.join(NODE_RUNTIME_DIR, 'node.exe');

require(path.join(__dirname, 'setup-node-runtime.cjs'));

function run(cmd, args, opts = {}) {
  const res = spawnSync(cmd, args, { stdio: 'inherit', ...opts });
  if (res.status !== 0) {
    process.exit(res.status ?? 1);
  }
}

if (!fs.existsSync(NODE_BINARY)) {
  console.error('[dsh-desktop] bundled node.exe not found at', NODE_BINARY);
  console.error('Download and extract https://nodejs.org/dist/v24.19.0/node-v24.19.0-win-x64.zip to node-runtime/');
  process.exit(1);
}

console.log('[dsh-desktop] preparing dsh runtime in', RUNTIME_DIR, 'using bundled node', NODE_BINARY);

fs.mkdirSync(RUNTIME_DIR, { recursive: true });

const pkgPath = path.join(RUNTIME_DIR, 'package.json');
if (!fs.existsSync(pkgPath)) {
  const pkg = {
    name: 'dsh-runtime',
    version: '1.0.0',
    private: true,
    type: 'commonjs',
    allowScripts: {
      '@deepseek-ai/dsh-subprocess-local@0.1.0-rc.6': true,
      'koffi@3.1.5': true,
      'node-pty@1.1.0': true,
      'protobufjs@7.6.5': true,
      '@google/genai@1.52.0': true,
    },
  };
  fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
}

const npmCli = path.join(NODE_RUNTIME_DIR, 'node_modules', 'npm', 'bin', 'npm-cli.js');
const env = {
  ...process.env,
  PATH: NODE_RUNTIME_DIR + path.delimiter + (process.env.PATH || ''),
};

run(NODE_BINARY, [npmCli, 'install', '@deepseek-ai/dsh@0.1.0-rc.6', '--no-audit', '--no-fund'], {
  cwd: RUNTIME_DIR,
  env,
});

console.log('[dsh-desktop] runtime ready');

