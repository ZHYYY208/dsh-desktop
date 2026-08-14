# 开发者文档（Development）

给维护者/贡献者看的构建、签名、发布说明。最终用户请直接看 [README](./README.md)。

本项目同时产出 **Windows**（Electron + NSIS）与 **Ubuntu Linux**（.deb）两个桌面版本，二者共用同一个 dsh npm 版本。

## Windows：本地构建

需要本机已安装 Node.js（仅用于运行构建工具）。

```powershell
npm install          # 安装 electron + electron-builder
npm run dist         # 自动准备运行时并打包 NSIS 安装器
```

`npm run dist` 会依次执行：

1. `scripts/setup-node-runtime.cjs` — 若缺失则自动下载解压独立 Node 24.19.0 到 `node-runtime/`
2. `scripts/prepare-runtime.cjs` — 用内置 Node 在 `runtime/` 里 `npm install @deepseek-ai/dsh`
3. `electron-builder --win nsis` — 打包出 `.exe` 安装器

产物：

```
dist/DSH Desktop-Setup-1.0.0.exe    # 安装器
dist/win-unpacked/DSH Desktop.exe   # 免安装版，可直接运行
```

本地调试运行：`npm start`

## Ubuntu Linux：本地构建

需要 `curl`、`tar`、`xz`、`python3`、`dpkg-deb`（Ubuntu 自带）。

```sh
bash linux/build-deb.sh --out linux/dist
```

脚本会：下载独立 Node 到 `linux/node-runtime/` → 用内置 Node 在 `linux/runtime/` 安装 `@deepseek-ai/dsh`（与 Windows 同一个 npm 版本）→ 组装并生成 `.deb`。

产物：`linux/dist/dsh-desktop_<版本>_<架构>.deb`

常用参数：

| Flag | 含义 | 默认 |
| --- | --- | --- |
| `--version V` | dsh npm 版本 | `0.1.0-rc.6` |
| `--node-version V` | 内置 Node 版本 | `24.19.0` |
| `--node-tarball FILE` | 使用已下载的 Node tarball | 自动从 nodejs.org 下载 |
| `--arch ARCH` | `amd64` / `arm64` | `dpkg --print-architecture` |
| `--out DIR` | 输出目录 | `linux/dist` |

本地验证安装包：

```sh
dpkg-deb -x linux/dist/*.deb /tmp/debext
/tmp/debext/opt/dsh-desktop/node/bin/node \
  /tmp/debext/opt/dsh-desktop/app/node_modules/@deepseek-ai/dsh/lib/bin.js --version
```

> 升级 dsh 版本：修改 `linux/build-deb.sh` 与 `scripts/prepare-runtime.cjs` 中的 `@deepseek-ai/dsh@<版本>`（两处需保持一致）。npm 上最新版本：`npm view @deepseek-ai/dsh version`。

## Windows 代码签名

Windows 代码签名需要数字证书。只有**商业受信任证书**（如 DigiCert、Sectigo）才能彻底消除 SmartScreen 警告。本项目支持两种方式：

### 1. 自签名证书（本地已启用）

已生成自签名证书 `build/selfsigned.pfx`（密码见 `build/cert-password.txt`，均已加入 `.gitignore`）并用 signtool 对本地产物签名 + DigiCert 时间戳。

- 验证签名：`Get-AuthenticodeSignature .\dist\"DSH Desktop-Setup-1.0.0.exe"`
- 信任该证书（可选）：双击安装 `selfsigned.pfx`，放入"受信任的根证书颁发机构"后，签名即被系统信任

### 2. GitHub Actions 自动签名

CI 流程已支持证书签名。在仓库 **Settings → Secrets and variables → Actions** 添加：

| Secret | 内容 |
|---|---|
| `WINDOWS_CERT_BASE64` | 证书 pfx 的 Base64 字符串（`certutil -encode selfsigned.pfx out.txt` 得到） |
| `WINDOWS_CERT_PASSWORD` | pfx 证书密码 |

设置后，每次 GitHub Actions 构建出的安装包都会自动签名。

## 发布到 GitHub Releases

三种方式：

1. **手动（任意平台）**：仓库页面 **Actions → build-installer / build-deb → Run workflow**，构建完成后安装包会作为 artifact 下载
2. **自动（tag 触发）**：推送版本标签即同时触发 Windows 与 Linux 两个构建：

   ```sh
   git tag v1.0.0
   git push origin v1.0.0
   ```

   - Linux：`build-deb` 工作流会自动创建 GitHub Release 并附上 `.deb`
   - Windows：`build-installer` 工作流产出 `.exe` artifact（可手动附加到 Release）

3. **本地构建后手动上传（Windows 签名包）**：CI 构建的安装包默认**不签名**（需先配置 Secrets）。官方 Release 上已签名的安装包由本机 `npm run dist` 构建后手动上传：在 Release 页面点 **Edit → 拖入安装包 → 发布**。

## 图标与应用外壳

- 图标由 `build/make-icons.py` 生成（纯 PIL，无需 numpy/ImageMagick）：现代渐变 + 玻璃拟态风格。修改后重新运行：

  ```sh
  python3 build/make-icons.py
  ```

  产物：`build/icon.png`（主图标）、`build/icon.ico`（Windows 多尺寸）、`build/icons/{32..512}.png`（Linux hicolor）、`electron/splash-icon.png`（启动屏）。
- Windows：Electron 启动时先显示渐变玻璃拟态启动屏（`electron/splash.html`），dsh 服务就绪后切入主窗口；主窗口 `show:false` + `ready-to-show` 避免白屏闪烁。
- Linux：`.deb` 自动安装多尺寸图标到 hicolor，应用菜单使用 `dsh-desktop` 图标。

## 目录结构

```
├── electron/
│   ├── main.cjs            # Electron 主进程：启动屏 + 拉起服务、打开窗口、退出时清理（Windows）
│   ├── splash.html         # 渐变玻璃拟态启动屏
│   └── splash-icon.png     # 启动屏图标（由 make-icons.py 生成）
├── scripts/
│   ├── setup-node-runtime.cjs   # 下载/解压独立 Node（Windows）
│   └── prepare-runtime.cjs      # 安装 @deepseek-ai/dsh 运行时（Windows）
├── linux/
│   ├── build-deb.sh        # 打包 .deb（Ubuntu Linux）
│   ├── dsh                 # Linux 的 dsh 启动器
│   ├── dsh-desktop         # Linux 桌面启动器（起服务 + 打开浏览器）
│   ├── dsh-desktop.desktop # 应用菜单入口
│   └── postinst            # 安装后刷新图标/桌面数据库
├── runtime/                # dsh CLI + 依赖（Windows 构建时生成，不入 git）
├── node-runtime/           # 独立 Node 24.19.0（Windows 构建时生成，不入 git）
├── linux/runtime/          # dsh CLI + 依赖（Linux 构建时生成，不入 git）
├── linux/node-runtime/     # 独立 Node 24.19.0（Linux 构建时生成，不入 git）
├── build/
│   ├── make-icons.py       # 图标生成脚本（渐变 + 玻璃拟态）
│   ├── icon.png            # 512x512 主图标
│   ├── icon.ico            # Windows 多尺寸图标
│   ├── icons/              # Linux hicolor 各尺寸图标
│   └── selfsigned.pfx      # 自签名证书（不入 git）
├── dist/                   # Windows 打包产物（不入 git）
├── linux/dist/             # Linux 打包产物（不入 git）
└── .github/workflows/
    ├── build.yml           # Windows NSIS 安装器
    └── build-linux.yml     # Ubuntu Linux .deb
```

## 常见问题

**Q: 打开后窗口是空白的？**
后台服务可能启动失败。正常情况下主进程会弹出错误对话框；也可以手动验证：运行 `dist\win-unpacked\resources\node-runtime\node.exe "dist\win-unpacked\resources\runtime\node_modules\@deepseek-ai\dsh\lib\bin.js" web --port 8080`，浏览器访问 `http://127.0.0.1:8080`。Linux 下查看 `~/.local/share/dsh-desktop/web.log`。

**Q: 我想升级 dsh 版本？**
同时修改 `scripts/prepare-runtime.cjs` 与 `linux/build-deb.sh` 中的 `@deepseek-ai/dsh@<版本>`，然后重新构建对应平台。npm 上最新版本：`npm view @deepseek-ai/dsh version`。

**Q: 端口冲突怎么办？**
Windows 默认用 `--port 0` 自动分配空闲端口；Linux 默认 3080，可通过 `DSH_WEB_PORT` 环境变量覆盖，无需修改代码。

## License

MIT。
