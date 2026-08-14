'use strict';

const { spawnSync } = require('node:child_process');
const https = require('node:https');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const ROOT = path.join(__dirname, '..');
const NODE_VERSION = 'v24.19.0';
const ARCH = process.arch === 'arm64' ? 'arm64' : 'x64';
const DIST_NAME = `node-${NODE_VERSION}-win-${ARCH}`;
const NODE_RUNTIME_DIR = path.join(ROOT, 'node-runtime');
const NODE_BINARY = path.join(NODE_RUNTIME_DIR, 'node.exe');

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

(async () => {
  if (fs.existsSync(NODE_BINARY)) {
    console.log('[dsh-desktop] node-runtime already present at', NODE_BINARY);
    return;
  }

  console.log(`[dsh-desktop] downloading standalone node ${NODE_VERSION} (${ARCH})`);
  const zipPath = path.join(os.tmpdir(), `${DIST_NAME}.zip`);
  const url = `https://nodejs.org/dist/${NODE_VERSION}/${DIST_NAME}.zip`;
  await download(url, zipPath);

  const staging = path.join(os.tmpdir(), `dsh-node-staging-${Date.now()}`);
  fs.mkdirSync(staging, { recursive: true });

  const pwsh = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
  run(pwsh, ['-NoProfile', '-Command', `Expand-Archive -LiteralPath '${zipPath}' -DestinationPath '${staging}' -Force`]);

  fs.renameSync(path.join(staging, DIST_NAME), NODE_RUNTIME_DIR);
  fs.rmSync(staging, { recursive: true, force: true });
  fs.rmSync(zipPath, { force: true });

  console.log('[dsh-desktop] node-runtime ready at', NODE_BINARY);
})();
