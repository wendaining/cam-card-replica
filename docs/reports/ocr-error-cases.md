# OCR 错误案例与原始输出

测量日期：2026-11-07；Xcode 27.2 / iPhone 18 Pro / iOS 27.0。案例来自同一批实际识别记录。

## zh-01.png

[原始图片](../../TestData/cards/zh-01.png) · [实际识别输入](evidence/ocr-2026-11-07/images/processed-zh-01.png) · [初始解析](evidence/ocr-2026-11-07/parsed/zh-01.png.json)

原文中的邮箱已出现 contactol，初始解析保留了识别文字。字符差异可以定位到 OCR 阶段。

### 实际 OCR 原文

```text
朱宏明
教授
同济大学
计算机科学与技术学院
手机：+86 138 0000 1234
电话：021-6000 1234
传真：021-6000 1235
Email: contactol@example.com
Web: www.example0l.com
Add：上海市杨浦区四平路1239号 200092
```

### 字段错误

| 字段 | GT | 实际初始结果 |
|---|---|---|
| 邮箱集合 | ["contact01@example.com"] | ["contactol@example.com"] |
| 网站 | ["www.example01.com"] | ["www.example0l.com"] |

实际人工修改值、修改数量、操作者、日期及附件：待填写。

## en-01.png

[原始图片](../../TestData/cards/en-01.png) · [实际识别输入](evidence/ocr-2026-11-07/images/processed-en-01.png) · [初始解析](evidence/ocr-2026-11-07/parsed/en-01.png.json)

原文中的公司名称已出现 Technologles，机构解析保留该字符串。

### 实际 OCR 原文

```text
David Chen
Technical Director
ABC Technologles
Platform Engineering
Mobile： +1 415 000 1234
Tel： +1415 000 8000
Email: david.chen@example.org
Email: info@example.org
Web:www.abc.example
Add: 500 Market Street, Suite 900, San Francisco, CA 94105
```

### 字段错误

| 字段 | GT | 实际初始结果 |
|---|---|---|
| 公司 | ["ABC Technologies"] | ["ABC Technologles"] |
| 座机集合 | ["+1 415 000 8000"] | ["+1415 000 8000"] |

实际人工修改值、修改数量、操作者、日期及附件：待填写。

## en-03-photo.jpg

[原始图片](../../TestData/cards/en-03-photo.jpg) · [实际识别输入](evidence/ocr-2026-11-07/images/processed-en-03-photo.png) · [初始解析](evidence/ocr-2026-11-07/parsed/en-03-photo.jpg.json)

原文中的姓名包含数字 1，照片变体存在旋转与透视。实际文字仍需由用户核对。

### 实际 OCR 原文

```text
Michae1 o'Brian
VP Sales
Bright Harbor Logistics
G1obal Accounts
Mobile: Mobile： +44 20 0000 9012
Te1： +49 30 00006000
Tel：
Emai1:Emai1:michael.obrian@example.org
Web: www.bright.example
Web：
Add: Friedrichstrasse 88,10117 Berlin, Germany
Add：
EN
```

### 字段错误

| 字段 | GT | 实际初始结果 |
|---|---|---|
| 地址 | ["Friedrichstrasse 88, 10117 Berlin, Germany"] | ["Add: Friedrichstrasse 88,10117 Berlin, Germany"] |
| 部门 | ["Global Accounts"] | ["G1obal Accounts"] |
| 姓名 | ["Michael O'Brian"] | ["Michae1 o'Brian"] |
| 座机集合 | ["+49 30 0000 6000"] | ["+49 30 00006000"] |

实际人工修改值、修改数量、操作者、日期及附件：待填写。

## zh-06.png

[原始图片](../../TestData/cards/zh-06.png) · [实际识别输入](evidence/ocr-2026-11-07/images/processed-zh-06.png) · [初始解析](evidence/ocr-2026-11-07/parsed/zh-06.png.json)

OCR 原文没有电话类型标签，初始解析依据号码格式将该号码标为座机，GT 将其标为传真。

### 实际 OCR 原文

```text
刘晓峰
合伙人
海通律师事务所
知识产权
+86 188 0000 2211
0755-2000 9013
contact06@example.com
www.example06.com
```

### 字段错误

| 字段 | GT | 实际初始结果 |
|---|---|---|
| 部门 | ["知识产权"] | [] |
| 传真集合 | ["0755-2000 9013"] | [] |
| 座机集合 | [] | ["0755-2000 9013"] |

实际人工修改值、修改数量、操作者、日期及附件：待填写。

[全部 OCR 证据](evidence/ocr-2026-11-07/README.md)与 [人工修改表](../submission/manual-corrections.csv)。
