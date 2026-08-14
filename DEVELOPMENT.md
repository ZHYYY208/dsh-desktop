# 开发者文档（Development）

给维护者/贡献者看的构建、签名、发布说明。最终用户请直接看 [README](./README.md)。

## 本地构建

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

## 代码签名

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

两种方式：

1. **手动**：仓库页面 **Actions → build-installer → Run workflow**，构建完成后 `DSH Desktop-Setup-*.exe` 会作为 artifact 下载
2. **自动（tag 触发）**：推送版本标签即触发 GitHub Actions 构建，产物同样作为 artifact 下载：

   ```powershell
   git tag v1.0.0
   git push origin v1.0.0
   ```

> CI 构建的安装包默认**不签名**（需先配置上述 Secrets）。官方 Release 上已签名的安装包由本机 `npm run dist` 构建后手动上传：在 Release 页面点 **Edit → 拖入安装包 → 发布**。

## 目录结构

```
├── electron/
│   └── main.cjs            # Electron 主进程：拉起服务、打开窗口、退出时清理
├── scripts/
│   ├── setup-node-runtime.cjs   # 下载/解压独立 Node
│   └── prepare-runtime.cjs      # 安装 @deepseek-ai/dsh 运行时
├── runtime/                # dsh CLI + 依赖（构建时生成，不入 git）
├── node-runtime/           # 独立 Node 24.19.0（构建时生成，不入 git）
├── build/
│   ├── icon.png            # 应用图标
│   └── selfsigned.pfx      # 自签名证书（不入 git）
├── dist/                   # 打包产物（不入 git）
└── .github/workflows/build.yml
```

## 常见问题

**Q: 打开后窗口是空白的？**
后台服务可能启动失败。正常情况下主进程会弹出错误对话框；也可以手动验证：运行 `dist\win-unpacked\resources\node-runtime\node.exe "dist\win-unpacked\resources\runtime\node_modules\@deepseek-ai\dsh\lib\bin.js" web --port 8080`，浏览器访问 `http://127.0.0.1:8080`。

**Q: 我想升级 dsh 版本？**
修改 `scripts/prepare-runtime.cjs` 中的 `@deepseek-ai/dsh@<版本>`，重新 `npm run dist`。npm 上最新版本：`npm view @deepseek-ai/dsh version`。

**Q: 端口冲突怎么办？**
应用默认用 `--port 0` 自动分配空闲端口，无需关心。

## License

MIT。
