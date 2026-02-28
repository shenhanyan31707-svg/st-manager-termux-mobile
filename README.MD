# ST Manager Termux Mobile（安卓移动端专用）

本目录是 **仅面向 Android + Termux** 的运行包，已剥离桌面端无关内容，适合直接拷贝到手机使用。

## 1. 目录说明

- `.next/`：Next.js 运行产物
- `server.js`：服务入口
- `app-config.json`：数据目录配置（默认 Android 共享目录）
- `scripts/`：运维脚本（启动、停止、状态、健康检查、日志轮转等）
- `termux/runit/`：`termux-services` 守护模板
- `install-termux.sh`：一键安装脚本（推荐）

默认运行策略：
- 监听地址：`127.0.0.1`
- 端口：`3456`
- 数据目录：`/storage/emulated/0/SillyTavern/default-user`

---

## 2. 前置条件（手机端）

请先在 Android 手机上安装：
1. `Termux`（建议 F-Droid 版本）
2. `Termux:API`（用于本地通知等能力）
3. 可选：`Termux:Boot`（后续若你要开机自启）

---

## 3. 一键安装（推荐）

### 3.1 把目录放到手机
建议路径：
```bash
~/apps/st-manager-termux-mobile
```

### 3.2 执行一键安装
```bash
cd ~/apps/st-manager-termux-mobile
bash install-termux.sh
```

安装脚本会自动完成：
1. 安装依赖包（`nodejs-lts`、`termux-services`、`curl`、`jq` 等）
2. 申请共享存储权限（`termux-setup-storage`）
3. 创建 SillyTavern 数据目录（`characters/worlds/chats`）
4. 重装依赖（`npm install --omit=dev`）
5. 赋予脚本执行权限
6. 启动服务并执行健康检查
7. 尝试接入 `runit` 守护

安装成功后访问：
```text
http://127.0.0.1:3456
```

---

## 4. 自定义安装参数（可选）

如需修改数据目录或端口，可在执行时覆盖环境变量：
```bash
cd ~/apps/st-manager-termux-mobile
DATA_PATH=/storage/emulated/0/SillyTavern/default-user PORT=3456 bash install-termux.sh
```

常用变量：
- `DATA_PATH`：SillyTavern 数据目录
- `PORT`：服务端口（默认 `3456`）
- `HOSTNAME`：监听地址（建议保持 `127.0.0.1`）

---

## 5. 日常运维命令

```bash
cd ~/apps/st-manager-termux-mobile

# 启动
bash scripts/start.sh

# 停止
bash scripts/stop.sh

# 查看状态（进程、监听端口、接口、最近日志）
bash scripts/status.sh

# 健康检查（检测 /api/stats 是否 success=true）
bash scripts/healthcheck.sh

# 日志轮转（默认保留 30 天，超 20MB 压缩）
bash scripts/log-rotate.sh

# 每日巡检（失败时通知 + 尝试重启）
bash scripts/daily-health.sh
```

也可使用 npm 快捷命令：
```bash
npm run termux:start
npm run termux:stop
npm run termux:status
npm run termux:health
npm run termux:log-rotate
npm run termux:daily-health
npm run termux:install-service
```

---

## 6. 守护进程（termux-services / runit）

### 6.1 安装守护配置
```bash
cd ~/apps/st-manager-termux-mobile
sv-enable
bash scripts/install-runit-service.sh
sv status st-manager
```

### 6.2 常用控制命令
```bash
sv up st-manager
sv down st-manager
sv restart st-manager
sv status st-manager
```

说明：
- 你手动 `kill` 主进程后，`runit` 会尝试自动拉起。
- 当前默认策略是“先手动验证，再守护托管”。

---

## 7. 移动端稳定性建议

1. 在 Android 设置里关闭 Termux 的电池优化  
2. 长时间运行时启用：
```bash
termux-wake-lock
```
3. 日常至少执行一次：
```bash
bash scripts/status.sh
```
4. 建议开启定时巡检（每 15 分钟）：
```bash
crontab -e
```
加入：
```cron
*/15 * * * * cd ~/apps/st-manager-termux-mobile && bash scripts/daily-health.sh >/dev/null 2>&1
```
然后启动 crond：
```bash
sv up crond
```

---

## 8. 常见问题与排障

### Q1：安装时报原生模块/ELF 不兼容（Next/SWC）
处理：
1. 使用 `proot-distro` 切换 Debian 环境
2. 在 Debian 内安装 Node LTS
3. 重新执行 `npm install --omit=dev` 和启动流程

### Q2：网页打不开
排查顺序：
1. `bash scripts/status.sh`
2. 确认监听是 `127.0.0.1:3456`
3. `bash scripts/healthcheck.sh`
4. 查看 `logs/app-YYYY-MM-DD.log`

### Q3：数据列表为空
排查：
1. 检查 `app-config.json` 的 `dataPath`
2. 确认目录下存在 `characters/worlds/chats`
3. 调用：
```bash
curl -fsS http://127.0.0.1:3456/api/config
```

### Q4：锁屏后服务被系统杀掉
处理：
1. 关闭 Termux 电池优化
2. 使用 `termux-wake-lock`
3. 使用 runit 守护 + 定时 `daily-health.sh`

---

## 9. 升级与回滚建议

升级建议：
1. 先备份数据目录：`/storage/emulated/0/SillyTavern/default-user`
2. 替换项目目录后重新执行：`bash install-termux.sh`
3. 验证 `status + healthcheck`

回滚建议：
1. `bash scripts/stop.sh`
2. 恢复上一版目录
3. 重新执行安装脚本

---

## 10. 安全提示

本项目默认仅监听 `127.0.0.1`，请勿改为 `0.0.0.0` 对外暴露。  
若后续需要局域网访问，建议先增加鉴权（令牌或反向代理认证）再开放端口。
