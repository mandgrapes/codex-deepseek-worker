# Codex DeepSeek Worker 插件：MVP 需求

## 1. 一句话定义

让 Codex 在需要时把一段经过筛选的任务上下文发送给 DeepSeek API，接收代码补丁，再由 Codex 审查、应用并验收。

插件的项目启用命令只有一句：

> 用 DeepSeek 当小弟

这是一条项目模式开关，不是任务命令。启用后，用户继续用正常方式提出项目需求，不需要反复提到 DeepSeek。

“项目模式”只表示项目中的任务默认考虑交给 DeepSeek；实际发送多少上下文由 Codex 根据任务需要决定。

## 2. 核心目标

- Codex 是唯一的主代理，负责理解仓库、拆分任务和最终验收。
- DeepSeek 只是远程推理服务，没有本地文件、终端或仓库访问权。
- 只有 Codex 明确放进请求正文的内容会发送给 DeepSeek API。
- DeepSeek 只返回建议或补丁，不直接修改真实仓库。

## 3. 最小用户体验

用户在项目中首次对 Codex 说：

> 用 DeepSeek 当小弟

插件在项目的 `AGENTS.md` 中保存一条最小的持久规则。以后用户只需正常提出需求，例如：

> 增加用户登录失败后的重试逻辑。

Codex 默认判断并拆分适合交给 DeepSeek 的实现工作。“机密内容不外发、DeepSeek 只返回补丁、Codex 负责验收”是默认行为，用户不需要每次重复说明。

Codex 执行：

1. 阅读真实仓库并确定任务边界。
2. 判断哪些工作适合交给 DeepSeek；涉及机密或不适合外发的部分由 Codex 自己处理。
3. 选择允许外发的代码片段，生成任务请求。
4. 调用插件中的 DeepSeek API 脚本。
5. 获取 DeepSeek 返回的 unified diff 和简短说明。
6. 检查补丁是否越界或包含可疑内容。
7. 由 Codex 应用补丁并运行测试。
8. 如果失败，最多携带必要且已脱敏的错误信息返工两次。
9. 向用户报告最终修改、测试结果和遗留风险。

## 4. MVP 结构

```text
codex-deepseek-worker/
├─ .codex-plugin/
│  └─ plugin.json
└─ skills/
   └─ deepseek-worker/
      ├─ SKILL.md
      ├─ agents/
      │  └─ openai.yaml
      └─ scripts/
         └─ invoke-deepseek.ps1
```

MVP 不使用 MCP Server。`SKILL.md` 规定编排流程，PowerShell 脚本负责一次 DeepSeek API 请求，以减少依赖和维护成本。

## 5. 脚本接口

```powershell
invoke-deepseek.ps1 `
  -InputFile  <sanitized-request.json> `
  -OutputFile <deepseek-response.json>
```

输入内容：

```json
{
  "task": "需要完成的具体任务",
  "constraints": ["不得修改公开接口"],
  "context": [
    {
      "path": "src/example.ts",
      "content": "允许发送的文件内容"
    }
  ],
  "test_expectations": ["npm test"]
}
```

输出内容：

```json
{
  "summary": "实现说明",
  "patch": "unified diff",
  "suggested_tests": ["npm test"],
  "risks": []
}
```

## 6. 必须遵守的安全边界

- 脚本只读取显式指定的输入 JSON，不接受仓库目录参数。
- 脚本不扫描仓库，不读取输入 JSON 中未包含的文件。
- API Key 只从用户级环境变量 `DEEPSEEK_WORKER_API_KEY` 读取。
- API Key 不写入仓库、输入文件、输出文件或日志。
- DeepSeek 返回的补丁不能由脚本自动应用。
- API 调用失败时不得修改工作区。

这套边界防止 DeepSeek 主动浏览本机。发送哪些上下文由 Codex 根据任务需要和用户规则决定，插件不额外设置文件类型、目录或内容黑名单。

## 7. API 约定

- 默认使用 DeepSeek 官方 API，也支持第三方 OpenAI Chat Completions 兼容服务。
- 用户级环境变量 `DEEPSEEK_WORKER_BASE_URL` 设置服务地址。
- 用户级环境变量 `DEEPSEEK_WORKER_API_KEY` 设置该服务的 API Key。
- 用户级环境变量 `DEEPSEEK_WORKER_MODEL` 设置服务商使用的模型名称，默认值为 `deepseek-v4-flash`。
- 插件只用于 DeepSeek V4 Flash；允许配置模型名称只是为了兼容中转服务的模型别名，不代表支持切换到其他模型。
- `BASE_URL` 未配置时默认使用 `https://api.deepseek.com`。
- 上游必须提供 OpenAI Chat Completions 兼容接口。
- 请求要求 DeepSeek 只返回符合约定的 JSON。
- 设置合理的超时、最大输入大小和最大输出长度。
- 暂不实现流式输出、并行请求和长会话记忆。

DeepSeek 官方配置：

```powershell
$env:DEEPSEEK_WORKER_BASE_URL = "https://api.deepseek.com"
$env:DEEPSEEK_WORKER_API_KEY = "your-deepseek-api-key"
$env:DEEPSEEK_WORKER_MODEL = "deepseek-v4-flash"
```

代码和任务上下文会发送给 `DEEPSEEK_WORKER_BASE_URL` 指向的服务商。使用第三方中转服务时，用户需要自行确认其隐私、日志留存和数据使用政策。

## 8. Codex 验收规则

Codex 不得仅根据 DeepSeek 的文字总结判定成功，必须：

- 检查实际补丁内容和修改范围。
- 拒绝修改未授权文件的补丁。
- 独立运行项目已有测试、lint 或类型检查。
- 检查新增代码是否泄露密钥或引入明显安全问题。
- 测试失败时向用户如实报告，不得伪造通过状态。

## 9. 明确不做

MVP 不包含：

- CC Switch 集成或 GUI 自动化。
- DeepSeek 直接访问本地文件和终端。
- 多 DeepSeek worker 并行执行。
- 自动提交 Git、创建 PR 或推送远端。
- 自动发送整个仓库或完整 Git diff。
- 多供应商路由、计费统计和图形界面。
- 在 DeepSeek V4 Flash 与其他模型之间切换。
- 无限制自动返工。

## 10. 完成标准

- 插件可被 Codex 正常加载。
- 说出“用 DeepSeek 当小弟”后，项目 `AGENTS.md` 会保存启用规则。
- 后续普通项目任务无需再次指定 DeepSeek。
- Codex 能按技能说明调用 PowerShell 脚本。
- 使用有效 API Key 时能得到结构化补丁结果。
- 缺少 API Key 或 API 失败时安全终止。
- DeepSeek 进程没有真实仓库访问能力。
- 补丁只在 Codex 审查后应用。
- Codex 能运行测试并输出最终验收报告。

## 11. 后续升级条件

只有在 MVP 已稳定使用、确实需要更强交互时，再考虑把脚本升级成 MCP Server。升级不应改变核心安全原则：DeepSeek 只能看到显式提供的内容，不能直接获得仓库权限。
