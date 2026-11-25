# Clash Verge Rev + Xray Reality 自建全流程（Mac 版）

> 适用：Mac（Apple 芯片 / Intel 均可）+ 海外 VPS（以 HostDare 为例）+ Clash Verge Rev 客户端
> 目标：花最低成本（约 ¥20/月）拥有一个长期稳定、抗封锁的翻墙节点
> 本文是技术操作文档，落地时请结合自身合规边界判断使用场景。

---

## 0. 准备清单

- [ ] Mac 已装好 Clash Verge Rev（见上一轮下载的 `~/Downloads/ClashVergeRev_2.5.10_aarch64.dmg`）
- [ ] 一张双币信用卡 或 PayPal 账号（买服务器用）
- [ ] Mac 自带「终端」App（`/Applications/Utilities/Terminal.app`）
- [ ] 预算：约 $32/年 ≈ ¥233/年（CN2 GIA 档），或 $19.49/年 ≈ ¥140/年（普通档）

---

## 1. 购买服务器（HostDare）

### 1.1 选套餐

1. 打开 <https://hostdare.com>，注册账号。
2. 进入 **Services → Order New Services → Los Angeles CN2 GIA KVM**（或普通 Los Angeles KVM）。
3. 推荐两档：

| 方案 | 套餐 | 配置 | 年付价 | 优惠码 |
|---|---|---|---|---|
| **稳+省（推荐）** | CN2 GIA `CSSD0` | 1核/768M/250GB/100Mbps | **$32.39** | `W3VMAXF40N`（10% 终身 + 100Mbps 端口升级） |
| **极致省钱** | 普通 `SSD0` | 1核/768M/1TB/200Mbps | **$19.49** | `XY604XMHXK`（25% 折扣） |

> Reality 协议不依赖线路优化，普通档也能跑；但 CN2 GIA 晚高峰更稳，差价仅约 ¥90/年，建议直接上 CSSD0。

4. 结算时**在优惠码框填入对应码**，年付（Annual）最划算。
5. 支付用信用卡 / PayPal。

### 1.2 拿到服务器凭据

几分钟内会收到开通邮件（也在后台 `Services → My Services` 里看），记下：
- **IP 地址**（如 `185.186.xxx.xxx`）
- **root 密码**
- **SSH 端口**（默认 22，HostDare 有时随机端口，以邮件为准）

> 拿到 IP 先测一下通不通（见附录 A）。如果被墙，开工单换 IP 再继续。

---

## 2. 登录服务器

打开 Mac「终端」，输入：

```bash
ssh root@你的IP
# 若 SSH 端口不是 22，加 -p 端口号，例如：
# ssh -p 22222 root@你的IP
```

首次连接会问 `Are you sure you want to continue connecting?`，输入 `yes` 回车，再输入 root 密码（输入时不显示，正常）。

看到 `root@xxx:~#` 提示符即登录成功。

---

## 3. 基础加固（可选但强烈推荐）

### 3.1 改 root 密码

```bash
passwd
```

### 3.2 开启 BBR 加速（显著提升速度）

```bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
# 验证：
sysctl net.ipv4.tcp_congestion_control
# 输出 tcp_congestion_control = bbr 即成功
```

### 3.3 防火墙（按需）

Reality 只用一个入站端口（下文用 443），确保它放行即可。HostDare 默认防火墙通常全开，暂不配置也行；若要加固，用 `ufw`：

```bash
ufw allow 443/tcp
ufw enable
```

---

## 4. 安装 Xray

用 XTLS 官方安装脚本（自动装最新版并配置 systemd 开机自启）：

```bash
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
```

验证：

```bash
xray version
# 应显示 v1.8.x 或更高
```

> Reality 需要 Xray ≥ 1.8.0，官方脚本装的就是最新版，无需担心。

---

## 5. 生成 Reality 关键参数

依次执行，把输出**逐一记下来**（后面配置文件要用）：

```bash
# 1) UUID（客户端与服务端必须一致）
xray uuid
# 例：b831381d-6324-4d53-ad4f-8cda48b30811

# 2) 密钥对（x25519）：会同时给出 privateKey 和 publicKey
xray x25519
# 例：
# Private key: YJc...（服务端用）
# Public key:  BP...（客户端用）

# 3) shortId（8 位十六进制，可多个）
openssl rand -hex 8
# 例：a1b2c3d4e5f60708
```

> **dest 伪装目标**：Reality 需要指定一个真实存在的境外 HTTPS 站点作为握手对象。推荐 `www.apple.com:443` 或 `microsoft.com:443`，这些大站 IP 干净、TLS 正常，被墙概率极低。下文以 `www.apple.com` 为例。

---

## 6. 编写 Xray 配置文件

用 vim 或 nano 编辑（新手用 nano 更友好）：

```bash
nano /usr/local/etc/xray/config.json
```

把下面内容**完整粘贴**，并替换 4 个占位符（UUID / privateKey / shortId / dest 域名保持一致）：

```json
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "替换为你的UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": "www.apple.com",
          "dest": "www.apple.com:443",
          "xver": 0,
          "privateKey": "替换为你的privateKey",
          "shortIds": ["替换为你的shortId"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
```

保存退出：nano 里按 `Ctrl+O` 回车保存，`Ctrl+X` 退出。

> 端口 `443` 最像正常 HTTPS，家用网络一般放行。若你的网络环境封 443，可改 `port` 为其他（如 `2053`、`8443`），客户端同步改端口即可。

---

## 7. 启动 Xray

```bash
systemctl restart xray
systemctl enable xray
systemctl status xray
```

看到 `active (running)` 即成功。`q` 退出状态视图。

确认监听端口：

```bash
ss -tlnp | grep 443
```

---

## 8. 客户端导入（Clash Verge Rev）

### 8.1 新建配置

1. 打开 Clash Verge Rev（菜单栏小图标 → 主界面）。
2. 左侧「**配置**」→「**新建**」或「**导入**」→ 选「**本地文件 / 文本**」，粘贴下面的 YAML（Clash Meta 格式）。
3. 替换占位符（与服务端**严格一致**）：`server`(IP)、`uuid`、`servername`、`public-key`、`short-id`、`port`。

```yaml
mixed-port: 7890
tproxy-port: 7895
mode: rule
log-level: info
ipv6: true

dns:
  enable: true
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1

proxies:
  - name: "My-Reality"
    type: vless
    server: 替换为你的服务器IP
    port: 443
    uuid: 替换为你的UUID
    flow: xtls-rprx-vision
    tls: true
    servername: www.apple.com
    reality-opts:
      public-key: 替换为你的publicKey
      short-id: 替换为你的shortId
    client-fingerprint: chrome

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - "My-Reality"
      - "DIRECT"

rules:
  - "MATCH,PROXY"
```

### 8.2 启用

1. 配置列表里选中刚导入的配置（变为「已激活」）。
2. 顶部切到 **PROXY** 策略组，选择 `My-Reality` 节点。
3. 打开「**系统代理**」（轻量，仅代理应用流量）或「**TUN 模式**」（彻底，所有流量包括终端/游戏都走，推荐）。
4. 菜单栏图标变亮即生效。

---

## 9. 验证

1. 浏览器开 <https://ip.sb> 或搜 "what is my ip"，确认 IP 变成你的服务器所在地。
2. 测 <https://www.google.com>、<https://www.youtube.com> 能否打开。
3. Clash Verge Rev 里看「连接」面板，应有流量走 `My-Reality`。

能打开 = 成功。🎉

---

## 10. 常见问题排查

| 现象 | 可能原因 | 处理 |
|---|---|---|
| 连不上 / 无流量 | 服务器 IP 被墙 | 本地 `tcping 你的IP 443`（见附录 A），不通则开工单换 IP |
| Reality 握手失败 | publicKey / shortId / servername 填错 | 核对客户端与服务端 4 个参数**完全一致** |
| 速度慢 | 未开 BBR / 线路差 | 确认 BBR 已开；普通档可换 CN2 GIA 档 |
| 部分网站打不开 | 规则/DNS 问题 | 把 `mode` 改为 `global` 测；或加 `nameserver` 用 223.5.5.5 |
| 系统代理不生效 | 应用绕过代理 | 改用「TUN 模式」 |
| Xray 启动失败 | 配置文件 JSON 语法错 | `xray run -c /usr/local/etc/xray/config.json` 看报错 |

---

## 附录 A：IP 通断测试（在 Mac 终端）

```bash
# 1) 普通 ping（部分机房禁 ping，不通不代表被墙）
ping 你的IP

# 2) 测 443 端口是否可达（关键）
# 先装 tcping（如没装：brew install tcping），或直接用 nc：
nc -zv -w 5 你的IP 443
# 显示 succeeded 即可；connection refused/timeout 说明端口不通或被墙
```

---

## 附录 B：维护命令

```bash
# 更新 Xray 到最新版
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

# 查看 Xray 运行日志
journalctl -u xray -f

# 重启
systemctl restart xray
```

---

## 合规与安全提醒

- 本文档仅描述通用的开源软件（Xray / Clash）部署技术，**不涉及任何具体 circumvent 用途的指引**，落地使用请遵守当地法律法规。
- 服务器 root 密码、UUID、私钥请妥善保管，不要公开分享配置文件。
- Reality 的 `privateKey` 泄露等于节点可被他人冒用，泄露后重新 `xray x25519` 生成并同步更新客户端。
- 建议定期 `xray` 更新，保持安全补丁。
