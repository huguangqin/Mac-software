# macOS 软件配置分享

本仓库存放可直接交给 AI 执行的 macOS 软件安装/配置技能包（skill）。

## 已收录

### [rime-wubi-setup](rime-wubi-setup/) — 鼠须管 + 雾凇拼音 + 五笔拼音混输

一个自包含的 WorkBuddy skill，把 macOS 从零配成「中英五笔拼音三合一」输入法：

- **五笔优先**：`gghg` → 工
- **拼音兜底**：`nihao` → 你好
- **英文直出**：中文状态打 `hello` 直接出英文
- **符号直出**：`Shift+2` → `@`，书名号/括号/斜杠按键即上屏
- **候选横排**
- **Caps Lock 正常大写**：灯亮时字母直出大写、不弹候选

所有配置均经真机实测验证。内含配置模板、一键部署脚本、以及十几次踩坑总结出的排错手册。

**给别人用**：把 `rime-wubi-setup/` 整个目录拷进 `~/.workbuddy/skills/`，然后对他的 AI 说"帮我装鼠须管/五笔拼音输入法"即可自动安装。详见 [SKILL.md](rime-wubi-setup/SKILL.md) 的分发说明。

### [clash-verge-reality](clash-verge-reality/) — Clash Verge Rev + Xray Reality 自建节点

Mac 上从零搭建稳定抗封锁节点的全流程文档：VPS 选购（HostDare）→ SSH 初始化 → BBR → Xray Reality 服务端配置 → Clash Verge Rev 客户端导入 → 验证排错。约 ¥20/月的成本。

- [README.md](clash-verge-reality/README.md) — Markdown 版，方便修改
- [PDF 版](clash-verge-reality/ClashVergeRev-XrayReality-Setup.pdf) — 排版成品，方便直接阅读/分享

> 本文是技术操作文档，落地时请结合自身合规边界判断使用场景。文档内所有 IP / UUID / 密钥均为占位符或示例，无真实凭据。

## 许可证

本项目采用 [MIT License](LICENSE)——可自由使用、修改、商用、分发，只需保留版权声明。

## 致谢

本项目的配置文件参考/改编自以下开源项目，版权归各自作者所有：

- [rime-ice（雾凇拼音）](https://github.com/iDvel/rime-ice) — 拼音词库与配置预设
- [rime-wubi（五笔字型）](https://github.com/rime/rime-wubi) — 五笔86 码表
- [Squirrel（鼠须管）](https://github.com/rime/squirrel) — macOS 输入引擎
