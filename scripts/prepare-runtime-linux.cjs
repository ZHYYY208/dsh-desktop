'use strict';

// Prepare the Linux dsh runtime for the Electron app:
//   1. download/extract a standalone Linux Node.js into node-runtime/
//   2. use that bundled node to `npm install @deepseek-ai/dsh` into runtime/
// Mirrors scripts/setup-node-runtime.cjs + scripts/prepare-runtime.cjs (Windows)
// but targets Linux (tar.xz layout: node-runtime/bin/node).
//
// The packaged Electron app reads these same folders from its resources dir,
// so the two platforms share the electron/main.cjs shell.

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const https = require('node:https');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const RUNTIME_DIR = path.join(ROOT, 'runtime');
const NODE_RUNTIME_DIR = path.join(ROOT, 'node-runtime');
const NODE_VERSION = 'v24.19.0';
const ARCH = process.arch === 'arm64' ? 'arm64' : 'x64';
const DIST_NAME = `node-${NODE_VERSION}-linux-${ARCH}`;
const NODE_BINARY = path.join(NODE_RUNTIME_DIR, 'bin', 'node');
const CACHE_DIR = path.join(ROOT, 'node_modules', '.cache', 'dsh-node');

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https
      .get(url, (res) => {
        if (res.statusCode !== 200) {
          reject(new Error(`GET ${url} -> HTTP ${res.statusCode}`));
          res.resume();
          return;
        }
        res.pipe(file);
        file.on('finish', () => file.close(() => resolve()));
      })
      .on('error', (err) => {
        fs.rmSync(dest, { force: true });
        reject(err);
      });
  });
}

function run(cmd, args, opts = {}) {
  const res = spawnSync(cmd, args, { stdio: 'inherit', ...opts });
  if (res.status !== 0) {
    process.exit(res.status ?? 1);
  }
}

async function ensureNode() {
  if (fs.existsSync(NODE_BINARY)) {
    console.log('[dsh-desktop] node-runtime already present at', NODE_BINARY);
    return;
  }
  console.log(`[dsh-desktop] downloading standalone node ${NODE_VERSION} (linux-${ARCH})`);
  const tarball = path.join(os.tmpdir(), `${DIST_NAME}.tar.xz`);
  const url = `https://nodejs.org/dist/${NODE_VERSION}/${DIST_NAME}.tar.xz`;
  await download(url, tarball).catch((err) => {
    console.error('[dsh-desktop] failed to download node:', err && err.message ? err.message : err);
    process.exit(1);
  });
  fs.mkdirSync(NODE_RUNTIME_DIR, { recursive: true });
  run('tar', ['-xJf', tarball, '-C', NODE_RUNTIME_DIR, '--strip-components=1']);
  fs.rmSync(tarball, { force: true });
  console.log('[dsh-desktop] node-runtime ready at', NODE_BINARY);
}

(async () => {
  await ensureNode();

  console.log('[dsh-desktop] preparing dsh runtime in', RUNTIME_DIR, 'using bundled node', NODE_BINARY);
  fs.rmSync(RUNTIME_DIR, { recursive: true, force: true });
  fs.mkdirSync(RUNTIME_DIR, { recursive: true });

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
  fs.writeFileSync(path.join(RUNTIME_DIR, 'package.json'), JSON.stringify(pkg, null, 2));

  const npmCli = path.join(NODE_RUNTIME_DIR, 'lib', 'node_modules', 'npm', 'bin', 'npm-cli.js');
  const env = {
    ...process.env,
    PATH: path.join(NODE_RUNTIME_DIR, 'bin') + path.delimiter + (process.env.PATH || ''),
  };

  run(NODE_BINARY, [npmCli, 'install', '@deepseek-ai/dsh@0.1.0-rc.6', '--no-audit', '--no-fund'], {
    cwd: RUNTIME_DIR,
    env,
  });

  console.log('[dsh-desktop] runtime ready');
})().catch((err) => {
  console.error('[dsh-desktop] failed to prepare runtime:', err && err.message ? err.message : err);
  process.exit(1);
});
