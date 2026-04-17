# Claude Code 插件/marketplace/memory 接口核验

研究日期：2026-04-17
目的：为 AI-driver v0.2 插件化改造锁定外部接口事实。所有下游任务引用本文。

---

## 1. Marketplace 分发模型（Codex CRITICAL#1 验证结果）

**结论：必须用 marketplace-first，不能用 `/plugin install <git-url>` 直装。**

### 用户安装流程（两步）
```
/plugin marketplace add <source>
/plugin install <plugin-name>@<marketplace-name>
```

`<source>` 支持：
- GitHub shorthand：`acme-corp/claude-plugins`
- Git URL：`https://gitlab.com/team/plugins.git`
- 本地路径：`./my-marketplace`
- Remote URL 直指 marketplace.json：`https://example.com/marketplace.json`（但相对路径 plugin source 会失效，不推荐）

### 对应 CLI（可脚本化）
```bash
claude plugin marketplace add <source>
claude plugin install <plugin>@<marketplace>
```

### 私有仓库支持
- 手动安装：靠现有 git credential helper（`gh auth login` / `git-credential-store` / ssh-agent）
- 后台自动更新：需要 `GITHUB_TOKEN` / `GITLAB_TOKEN` 等环境变量

### 团队自动化（关键）
`.claude/settings.json` 里声明：

```json
{
  "extraKnownMarketplaces": {
    "ai-driver": {
      "source": {
        "source": "github",
        "repo": "HuMoran/AI-driver"
      }
    }
  },
  "enabledPlugins": {
    "ai-driver@ai-driver": true
  }
}
```

用户 trust project folder 时会自动提示安装。

---

## 2. Marketplace 清单 schema

### 文件位置
`<repo-root>/.claude-plugin/marketplace.json`

### 必填字段
```json
{
  "name": "ai-driver",              // kebab-case，不能是保留名
  "owner": { "name": "HuMoran" },   // email 可选
  "plugins": [
    {
      "name": "ai-driver",
      "source": "./plugins/ai-driver"
    }
  ]
}
```

### 保留名黑名单（不能用）
`claude-code-marketplace`、`claude-code-plugins`、`claude-plugins-official`、`anthropic-marketplace`、`anthropic-plugins`、`agent-skills`、`knowledge-work-plugins`、`life-sciences`；冒充 anthropic 的也会被拒。

`ai-driver` 可用。

### 可选 metadata
- `metadata.description` / `metadata.version` / `metadata.pluginRoot`

### Plugin 条目完整字段
除 `name` + `source` 外可加：`description`、`version`、`author`、`homepage`、`repository`、`license`、`keywords`、`category`、`tags`、`strict`，以及组件字段 `skills`/`commands`/`agents`/`hooks`/`mcpServers`/`lspServers`。

### `strict` 字段
- `true`（默认）：`plugin.json` 和 marketplace entry 的组件定义合并
- `false`：marketplace entry 是唯一定义；plugin 目录里如果还有 `plugin.json` 声明组件会冲突失败

### 本地路径 source 规则
- 必须以 `./` 开头
- 相对 marketplace 根目录（不是 `.claude-plugin/`）
- 不能用 `../`

---

## 3. plugin.json 清单 schema

### 文件位置
`<plugin-root>/.claude-plugin/plugin.json`

### 是否必须
**否。** manifest 可省略；Claude Code 会自动发现默认目录（`skills/`、`commands/`、`agents/` 等），插件名取自目录名。

### 若保留 manifest：只有 `name` 必填
```json
{ "name": "ai-driver" }
```

### 可选字段
`version`、`description`、`author{name, email, url}`、`homepage`、`repository`、`license`、`keywords`；以及组件路径覆盖字段。

### 版本字段双写警告
`plugin.json.version` 和 marketplace entry 的 `version` 都写会导致 manifest 静默覆盖 marketplace。推荐：**相对路径 plugin 把 version 写在 marketplace entry；其他 source 写在 plugin.json**。

---

## 4. 插件目录布局

```
<plugin-root>/
├── .claude-plugin/
│   └── plugin.json            # 仅放 manifest（可选）
├── skills/                    # 推荐：skills，每个是目录，含 SKILL.md
│   └── <name>/SKILL.md
├── commands/                  # 兼容：commands 是扁平 .md 文件
│   └── <name>.md
├── agents/
├── hooks/hooks.json
├── .mcp.json
├── .lsp.json
├── monitors/monitors.json
├── bin/                       # 可执行文件，会加入 Bash PATH
└── scripts/
```

**关键约束：**
- 组件目录必须在插件根，**不能**放 `.claude-plugin/` 里
- 插件安装时复制到 `~/.claude/plugins/cache`
- **不能用 `../` 引用外部文件**（会找不到）
- 需要跨插件共享文件：用 symlink，缓存会保留 symlink 而非 dereference

### `skills/` vs `commands/`
文档原话："Skills as flat Markdown files. Use `skills/` for new plugins"。但示例代码多用 `commands/`，两者都能工作。

**决策**：AI-driver v0.2 继续用 `commands/`（迁移成本低）。v0.3 再评估是否迁到 `skills/`。

### 环境变量
- `${CLAUDE_PLUGIN_ROOT}` — 插件安装路径（版本更新时变）
- `${CLAUDE_PLUGIN_DATA}` — 持久数据路径（跨更新保留）

---

## 5. 命令命名空间

### 文档说什么
Agents 是 `<plugin-name>:<agent-name>` 格式（文档原文）。

### 命令怎么命名空间
文档示例里**没有直接说**命令会被自动加 `<plugin>:` 前缀。但 OpenAI codex 插件在 commands/ 下有 `setup.md`、`rescue.md`，用户调用是 `/codex:setup`、`/codex:rescue`（根据 SessionStart hook 输出）。

**结论**：命令确实按 `/<plugin-name>:<command-file-basename>` 调用。AI-driver 的 `commands/run-spec.md` → `/ai-driver:run-spec`。

---

## 6. CLAUDE.md vs AGENTS.md（Codex HIGH#1 验证）

**结论：Claude Code 只读 CLAUDE.md，不读 AGENTS.md。必须用 `@AGENTS.md` 导入语法兼容。**

### 文档原话
> Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If your repository already uses `AGENTS.md` for other coding agents, create a `CLAUDE.md` that imports it so both tools read the same instructions without duplicating them.

### 推荐模板
```markdown
<!-- CLAUDE.md -->
@AGENTS.md

## Claude Code

Use plan mode for changes under `src/billing/`.
```

### `@path` 导入语法
- 相对或绝对路径
- 相对路径基于**包含导入的文件**的目录
- 最多递归 5 层
- 首次遇到外部导入会弹审批对话框

### 加载顺序
CLAUDE.md → 按目录树从当前工作目录向上走，每层的 CLAUDE.md 和 CLAUDE.local.md 都会加载。

### `.claude/rules/`
- 无条件 rules：启动时加载
- 带 `paths:` frontmatter 的 rules：只在 Claude 读到匹配文件时加载（省 context）

---

## 7. 对 AI-driver v0.2 的设计决策

基于上述事实，**修正/确认**如下：

| 设计点 | v0.2 原方案 | 修正 | 理由 |
|---|---|---|---|
| 分发 | `/plugin install <git-url>` | `/plugin marketplace add` + `/plugin install ai-driver@ai-driver` | 文档规定 |
| 仓库布局 | `plugins/ai-driver/` 子目录 | **保留**（`.claude-plugin/marketplace.json` 在根，插件在 `plugins/ai-driver/`） | 文档示例 |
| plugin.json | 4 字段 | **只写 `name` + `version`**，其他靠 marketplace entry | 减少双写漂移 |
| CLAUDE.md 策略 | AGENTS.md 取代 CLAUDE.md | **CLAUDE.md 主文件** + 内容含 `@AGENTS.md` 导入 + Claude 专属补充 | 文档规定 |
| 命令目录 | `commands/` | 保留 `commands/`（v0.2 不迁 skills） | 文档说兼容；迁移成本低 |
| 团队启用 | 手动 | init 写 `.claude/settings.json` 的 `extraKnownMarketplaces` + `enabledPlugins` | 文档支持 |
| 外部文件依赖 | 无约束 | **所有路径必须在插件根内**，模板也复制进 `plugins/ai-driver/templates/` | 缓存约束 |

---

## 8. marketplace.json 最终形态（待 Phase 1 落地）

```json
{
  "name": "ai-driver",
  "owner": {
    "name": "HuMoran",
    "url": "https://github.com/HuMoran"
  },
  "metadata": {
    "description": "Language-agnostic AI-driven development framework. Humans write specs, AI does the rest.",
    "version": "0.2.0"
  },
  "plugins": [
    {
      "name": "ai-driver",
      "source": "./plugins/ai-driver",
      "description": "Claude Code plugin for AI-driver framework",
      "version": "0.2.0",
      "author": { "name": "HuMoran" },
      "homepage": "https://github.com/HuMoran/AI-driver",
      "license": "MIT"
    }
  ]
}
```

---

## 9. 引用来源

- [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Memory](https://code.claude.com/docs/en/memory)
- 本地样例：`/Users/tao/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/.claude-plugin/marketplace.json`
- 本地样例：`/Users/tao/.claude/plugins/cache/openai-codex/codex/1.0.1/.claude-plugin/plugin.json`
