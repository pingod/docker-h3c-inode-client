# H3C iNode VPN 客户端 Docker 镜像

多架构（amd64/arm64）的 H3C iNode 智能客户端容器：KasmVNC 网页远程桌面 + iNode 客户端 + Dante SOCKS5 代理。

![H3C iNode Client](./assets/figure.png)

## 组件版本

| 组件 | 版本 |
|------|------|
| 基础镜像 | `ubuntu:26.04` (LTS) |
| KasmVNC | `1.5.2` (`ubuntu_resolute` 构建) |
| H3C iNode | `7.3 (E0626)` |
| Dante | `1.4.4` |

## 镜像地址

- `ghcr.io/pingod/docker-h3c-inode-client:latest`（linux/amd64 + linux/arm64 多架构）
- 其他标签：分支名、`sha-<短SHA>`、`v*` 版本号

## 功能特性

- amd64 / arm64 双架构，GitHub Actions 自动构建并推送 GHCR
- iNode 客户端运行在 KasmVNC 提供的 X 会话中，浏览器直接访问，无需安装 VNC 客户端
- iNode 拨通后自动拉起 Dante SOCKS5 代理（监听 `1080`，出口 `tun0`）
- iNode 连接配置、日志可持久化到宿主机

## 端口

| 端口 | 说明 |
|------|------|
| `5901` | KasmVNC 网页端口（HTTP/WebSocket） |
| `1080` | Dante SOCKS5 代理，仅在 `tun0` 获得 IPv4 后启动 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `USER` | `vncuser` | KasmVNC 登录用户名 |
| `PASSWORD` | `password` | KasmVNC 登录密码，至少 6 位 |
| `PROTOCOL` | `http` | KasmVNC 协议：`http` / `https` / `vnc` |
| `GEOMETRY` | `1280x720` | 桌面分辨率 |
| `DISPLAY_NUM` | `1` | X 显示编号（`:1`） |

## 使用

### Docker

```bash
docker run -d \
  --name h3c-inode \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  -p 5901:5901 \
  -p 1080:1080 \
  -e USER=myuser \
  -e PASSWORD=mypassword \
  -v "$(pwd)/vpn_data:/opt/apps/com.client.inode.amd/files/clientfiles/7000" \
  ghcr.io/pingod/docker-h3c-inode-client:latest
```

arm64 设备把卷路径换成 `/opt/apps/com.client.inode.arm/files/clientfiles/7000`。

### docker-compose

```yaml
services:
  h3c-inode:
    image: ghcr.io/pingod/docker-h3c-inode-client:latest
    container_name: h3c-inode
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    ports:
      - "5901:5901"
      - "1080:1080"
    environment:
      USER: myuser
      PASSWORD: mypassword
    volumes:
      - ./vpn_data:/opt/apps/com.client.inode.amd/files/clientfiles/7000
    restart: unless-stopped
```

## 使用流程

1. 浏览器打开 `http://<宿主机IP>:5901`，用 `USER` / `PASSWORD` 登录。
2. 在桌面中打开 iNode 客户端，新建 SSL VPN / 802.1X 连接并登录。
3. iNode 建立 `tun0` 后，容器内自动启动 Dante；本机或其他机器可用 SOCKS5 访问内网：

```bash
curl --socks5-hostname 127.0.0.1:1080 http://内网地址/
```

用户名密码每次启动时由 `USER` / `PASSWORD` 写入容器内的 `~/.kasmpasswd`，不会持久化；挂载卷用于保留 iNode 的连接配置与日志。

## 构建

```bash
# 本地单架构构建（可选国内镜像加速）
docker build \
  --build-arg TARGETARCH=amd64 \
  --build-arg APT_MIRROR=mirrors.ustc.edu.cn \
  -t h3c-inode-client:latest .

# 多架构 + 推送由 GitHub Actions 完成
git push origin main
```

工作流 `.github/workflows/docker-build-push.yml`：

- push 到 `main`、PR、手动触发均构建 `linux/amd64` + `linux/arm64`
- 推送 `ghcr.io/<owner>/<repo>`：`latest`、分支名、短 SHA、语义化版本标签
- PR 只构建不推送；使用 GHA 缓存

## iNode 安装包来源

H3C 官网的 Linux 安装包需要登录后下载，容器构建使用仓库内的 `assets/inode.<arch>_E0626.deb`（目前能获取到的最新 Linux 客户端；更新的 E06xx 版本只在 H3C 登录下载中心提供）。如需升级：

1. 从 H3C 官网下载对应的 iNode 管理中心 / 客户端包（`E06xx`）；
2. 生成或取出 `com.client.inode.{amd,arm}_E06xx.deb`，放入 `assets/`；
3. 修改 `Dockerfile` 中的 `ARG INODE_VERSION` 后重新构建。

## 许可证

MIT License
