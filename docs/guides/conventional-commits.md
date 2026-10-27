# 提交规范

## 格式

```
<type>(<scope>): <subject>

<body 可选>

Refs: <T编号或 spec 章节>
```

- `type`：`feat|fix|refactor|test|docs|build|ci|chore|perf|style`
- `scope`：模块名，小写，如 `parser`、`store`、`scanner`、`docs`
- `subject`：祈使句、英文、小写开头、不加句号、≤ 72 字符（中文也可）
- `body`：说清"为什么"，不写"改了什么"（diff 已经说明）

## 例子

```
feat(parser): classify phones by label before pattern

Labels ("Fax:", "手机：") are stronger evidence than digit patterns and were
being ignored, which mislabelled fax numbers as mobiles.

Refs: T10
```

```
fix(scanner): keep permission state after returning from settings

Refs: T03
```

## 校验

`.githooks/commit-msg` 会拒绝不合规的提交。安装：

```bash
make hooks
```

临时绕过（仅在确有必要时）：`git commit --no-verify`，并在 PR 描述里说明原因。
