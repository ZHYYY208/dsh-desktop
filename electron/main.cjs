'use strict';

// The app installs under "/opt/DSH Desktop" (productName keeps a space), and
// Chromium's SUID sandbox helper cannot exec a path containing a space, which
// fatally aborts the zygote at startup ("LaunchProcess: failed to execvp").
// Disabling the sandbox is the standard fix for such install paths.
const { app, BrowserWindow, dialog } = require('electron');
app.commandLine.appendSwitch('no-sandbox');
const { spawn } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

const isPackaged = app.isPackaged;
const RESOURCES_DIR = isPackaged ? process.resourcesPath : path.join(__dirname, '..');
const RUNTIME_DIR = path.join(RESOURCES_DIR, 'runtime');
// Windows runtime extracts to node-runtime/node.exe; Linux to node-runtime/bin/node.
const NODE_BINARY = process.platform === 'win32'
  ? path.join(RESOURCES_DIR, 'node-runtime', 'node.exe')
  : path.join(RESOURCES_DIR, 'node-runtime', 'bin', 'node');

const CLI_ENTRY = path.join(
  RUNTIME_DIR,
  'node_modules',
  '@deepseek-ai',
  'dsh',
  'lib',
  'bin.js'
);

let childProcess = null;
let mainWindow = null;
let splashWindow = null;

function log(...args) {
  console.log('[dsh-desktop]', ...args);
}

function errlog(...args) {
  console.error('[dsh-desktop]', ...args);
}

function runtimeReady() {
  return fs.existsSync(CLI_ENTRY) && fs.existsSync(NODE_BINARY);
}

function startServer() {
  return new Promise((resolve, reject) => {
    log('starting dsh web server from', CLI_ENTRY);

    const proc = spawn(NODE_BINARY, [CLI_ENTRY, 'web', '--host', '127.0.0.1', '--port', '0'], {
      cwd: RUNTIME_DIR,
      env: { ...process.env },
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    });

    childProcess = proc;

    let stdout = '';
    let stderr = '';
    let settled = false;

    const tryResolve = () => {
      if (settled) return;
      const match = stdout.match(/http:\/\/(127\.0\.0\.1|localhost):(\d+)/);
      if (match) {
        settled = true;
        resolve(`http://${match[1]}:${match[2]}`);
      }
    };

    proc.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
      process.stdout.write(chunk);
      tryResolve();
    });
    proc.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
      process.stderr.write(chunk);
    });
    proc.on('error', (err) => {
      errlog('failed to spawn dsh process:', err);
      if (!settled) {
        settled = true;
        reject(err);
      }
    });
    proc.on('exit', (code, signal) => {
      log('dsh process exited', code, signal);
      if (!settled) {
        settled = true;
        reject(new Error(`dsh exited before starting (code ${code}).\n${stderr}`));
      }
    });

    setTimeout(() => {
      if (!settled) {
        settled = true;
        reject(new Error('timed out waiting for the dsh server to start.\n' + stderr));
      }
    }, 60000);
  });
}

function stopServer() {
  if (childProcess) {
    log('stopping dsh server');
    try {
      childProcess.kill();
    } catch {
      // ignore
    }
    childProcess = null;
  }
}

async function createSplash() {
  splashWindow = new BrowserWindow({
    width: 460,
    height: 300,
    frame: false,
    transparent: true,
    resizable: false,
    show: false,
    alwaysOnTop: true,
    center: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  splashWindow.loadFile(path.join(__dirname, 'splash.html'));
  splashWindow.once('ready-to-show', () => splashWindow.show());
  splashWindow.on('closed', () => {
    splashWindow = null;
  });
}

function closeSplash() {
  if (splashWindow) {
    splashWindow.close();
    splashWindow = null;
  }
}

function createWindow(url) {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 860,
    minWidth: 900,
    minHeight: 600,
    title: 'DSH Desktop',
    show: false,
    backgroundColor: '#0d1630',
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.setMenuBarVisibility(false);

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    require('electron').shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    closeSplash();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
    stopServer();
  });

  mainWindow.loadURL(url);
}

async function boot() {
  if (!runtimeReady()) {
    closeSplash();
    dialog.showErrorBox(
      'DSH Desktop',
      'The dsh runtime is missing.\n\nRun "npm run prepare:runtime" before launching.'
    );
    app.quit();
    return;
  }

  createSplash();

  try {
    const url = await startServer();
    await createWindow(url);
  } catch (err) {
    errlog('failed to boot:', err);
    closeSplash();
    dialog.showErrorBox('DSH Desktop', 'Failed to start the dsh server:\n\n' + err.message);
    app.quit();
  }
}

app.whenReady().then(boot);

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0 && mainWindow === null) {
    boot();
  }
});

app.on('before-quit', () => {
  stopServer();
});

app.on('window-all-closed', () => {
  stopServer();
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
