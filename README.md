# DSH Desktop

DeepSeek Harness（`dsh`）的桌面客户端，支持 **Windows** 与 **Ubuntu Linux**。

一个开箱即用的本地 AI 助手桌面应用：把官方 [deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 的完整 Web 界面封装成原生桌面程序，双击即可使用，无需安装 Node.js 或任何额外环境。

## 功能特性

- ✅ **免环境安装** — 内置独立 Node.js 运行环境，装完即用
- ✅ **完整功能** — 会话、工具调用、文件操作、终端、技能（Skills）等 deepseek-harness 全部能力
- ✅ **本地运行** — 数据全部保存在本机，不经过任何第三方服务器
- ✅ **界面友好** — 全新渐变玻璃拟态图标；Windows 原生窗口 + 渐变启动屏；Linux 默认浏览器打开
- ✅ **自动端口** — Windows 自动分配空闲端口；Linux 默认 `127.0.0.1:3080`（可配置）

## 下载安装

前往 [GitHub Releases](https://github.com/ZHYYY208/dsh-desktop/releases) 页面，根据你的系统选择安装包。

### Windows

1. 下载最新版安装包：`DSH.Desktop-Setup-<版本>.exe`
2. 双击运行，按提示完成安装（可自定义安装目录）
3. 从开始菜单或桌面快捷方式打开 **DSH Desktop**

> **遇到 SmartScreen 提示？** 安装包使用自签名证书，首次运行请点击 **「更多信息」→「仍要运行」**。

### Ubuntu Linux

1. 下载最新版安装包：`dsh-desktop_<版本>_amd64.deb`
2. 安装：

   ```sh
   sudo dpkg -i dsh-desktop_<版本>_amd64.deb
   sudo apt-get install -f   # 如提示依赖需修复
   ```

3. 在应用菜单中打开 **DSH Desktop**，或运行 `dsh-desktop`

> **为什么这么大？** 安装包内自带完整 Node.js 运行时，因此无需在系统里安装 Node。

## 系统要求

- **Windows**：Windows 10 / 11（64 位）
- **Ubuntu Linux**：Ubuntu 20.04+（x86_64 / aarch64），安装后约占用 150MB 磁盘空间（Windows 安装后约 600MB）

## 使用说明

- 首次启动会自动完成初始化，随后进入聊天界面
- 数据默认保存在 `C:\Users\<你的用户名>\.dsh`（Windows）或 `~/.dsh`（Linux），卸载时不会自动删除，如需清理请手动删除该文件夹
- 会话、配置等均由应用自动管理，一般无需手动操作
- Linux 命令行下也可直接使用完整 CLI：`dsh --help`

## 卸载

- **Windows**：打开 **设置 → 应用 → 已安装的应用**，找到「DSH Desktop」，点击卸载即可
- **Ubuntu Linux**：

  ```sh
  sudo apt remove dsh-desktop
  ```

## 常见问题

**Q：打开后窗口是空白的？**
极少数情况下本地服务可能启动失败。请彻底关闭应用后重新打开；仍不行的话，请在仓库提交 [Issue](https://github.com/ZHYYY208/dsh-desktop/issues) 并附上截图。Linux 下也可查看日志：`~/.local/share/dsh-desktop/web.log`。

**Q：SmartScreen 总是弹"未知发布者"？**
因为目前使用自签名证书签名。要彻底消除提示，需要商业代码签名证书（收费）。在获得正式证书前，点「更多信息 → 仍要运行」即可正常使用。

**Q：我的数据和配置存在哪里？**
`C:\Users\<你的用户名>\.dsh`（Windows）或 `~/.dsh`（Linux）。备份该文件夹即可备份全部会话数据。

**Q：如何升级到新版本？**
关注 [Releases](https://github.com/ZHYYY208/dsh-desktop/releases) 页面，下载新版安装包直接覆盖安装即可，数据不会丢失。

**Q：Linux 下端口被占用怎么办？**
默认端口为 3080。可通过环境变量改用其它端口再启动：

```sh
DSH_WEB_PORT=8080 dsh-desktop
```

## 反馈

使用中遇到问题或有建议，欢迎在 [GitHub Issues](https://github.com/ZHYYY208/dsh-desktop/issues) 提交。

## License

本项目基于 MIT 协议开源。DeepSeek Harness 相关版权归其原作者所有。

---

维护者/开发者请参阅 [DEVELOPMENT.md](./DEVELOPMENT.md)。
