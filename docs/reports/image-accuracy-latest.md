# 图像到字段：语料 v2 实测

测量日期：2026-11-07；Xcode 27.2 / iPhone 18 Pro / iOS 27.0；图片数量：76。

[OCR 原始证据与识别输入](evidence/ocr-2026-11-07/README.md)包含逐图文字、位置、置信度、初始解析及图片哈希。

字段以完整值集合比较，忽略大小写及首尾空白，保留电话号码内部格式。字段错值同时计入漏值与多值。

“全部正确”包含原本缺失且输出为空的字段；“已印字段正确”仅统计印有该字段的图片。

| 图片组 | 字段 | 全部正确 | 已印字段正确 | 缺失误填 | 漏值数 | 多值数 |
|---|---|---:|---:|---:|---:|---:|
| flat | address | 32/50 | 19/37 | 0/13 | 18 | 18 |
| flat | company | 47/50 | 47/50 | 0/0 | 3 | 3 |
| flat | department | 41/50 | 25/34 | 0/16 | 9 | 1 |
| flat | emails | 32/50 | 32/50 | 0/0 | 19 | 16 |
| flat | fax | 45/50 | 6/11 | 0/39 | 5 | 0 |
| flat | jobTitle | 47/50 | 47/50 | 0/0 | 3 | 3 |
| flat | mobile | 45/50 | 45/50 | 0/0 | 1 | 5 |
| flat | name | 49/50 | 49/50 | 0/0 | 1 | 1 |
| flat | office | 48/50 | 22/23 | 1/27 | 1 | 2 |
| flat | website | 47/50 | 32/35 | 0/15 | 3 | 3 |
| occluded | address | 5/10 | 2/7 | 0/3 | 5 | 5 |
| occluded | company | 9/10 | 9/10 | 0/0 | 1 | 1 |
| occluded | department | 8/10 | 5/7 | 0/3 | 2 | 0 |
| occluded | emails | 6/10 | 6/10 | 0/0 | 4 | 3 |
| occluded | fax | 8/10 | 1/3 | 0/7 | 2 | 0 |
| occluded | jobTitle | 9/10 | 9/10 | 0/0 | 1 | 1 |
| occluded | mobile | 8/10 | 8/10 | 0/0 | 0 | 2 |
| occluded | name | 10/10 | 10/10 | 0/0 | 0 | 0 |
| occluded | office | 10/10 | 3/3 | 0/7 | 0 | 0 |
| occluded | website | 8/10 | 5/7 | 0/3 | 2 | 2 |
| occluded-photo | address | 3/4 | 2/3 | 0/1 | 1 | 1 |
| occluded-photo | company | 4/4 | 4/4 | 0/0 | 0 | 0 |
| occluded-photo | department | 4/4 | 2/2 | 0/2 | 0 | 0 |
| occluded-photo | emails | 1/4 | 1/4 | 0/0 | 3 | 3 |
| occluded-photo | fax | 4/4 | 1/1 | 0/3 | 0 | 0 |
| occluded-photo | jobTitle | 3/4 | 3/4 | 0/0 | 1 | 1 |
| occluded-photo | mobile | 4/4 | 4/4 | 0/0 | 0 | 0 |
| occluded-photo | name | 4/4 | 4/4 | 0/0 | 0 | 0 |
| occluded-photo | office | 4/4 | 1/1 | 0/3 | 0 | 0 |
| occluded-photo | website | 2/4 | 2/4 | 0/0 | 2 | 2 |
| photo | address | 4/12 | 2/10 | 0/2 | 8 | 8 |
| photo | company | 12/12 | 12/12 | 0/0 | 0 | 0 |
| photo | department | 10/12 | 5/7 | 0/5 | 2 | 1 |
| photo | emails | 8/12 | 8/12 | 0/0 | 5 | 5 |
| photo | fax | 12/12 | 2/2 | 0/10 | 0 | 0 |
| photo | jobTitle | 11/12 | 11/12 | 0/0 | 1 | 1 |
| photo | mobile | 12/12 | 12/12 | 0/0 | 0 | 0 |
| photo | name | 11/12 | 11/12 | 0/0 | 1 | 1 |
| photo | office | 10/12 | 2/4 | 0/8 | 2 | 2 |
| photo | website | 9/12 | 7/10 | 0/2 | 3 | 3 |

[逐图字段比较](image-accuracy-latest.json)；[全部维度统计](evidence/ocr-2026-11-07/metrics.csv)。

图片来自确定性生成的合成语料。真机拍照质量、正版相同输入识别结果及人工修改次数仍待填写。
