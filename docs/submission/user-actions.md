# 需要本人填写的资料

1. **提交信息**：把 `final-signoff.md` 复制为 final-signoff.local.md 后填写姓名、学号、日期和演示结果。
2. **人工修改记录**：把 `manual-corrections.csv` 复制为 manual-corrections.local.csv 后填写操作者、修改日期和证据位置。

两个 `.local` 文件已被 `.gitignore` 排除，不会进入 Git；`make package` 打包时会优先使用它们，没有本地副本时使用仓库里的空白模板。

TRAE 使用记录已经归档在 [TRAE 使用记录](../ai-collaboration/trae-record.md)。正版 Android 的 76 张同图识别及网页管理验证已经完成。相机权限已在 Xcode 模拟器验证，无需准备 iPhone；真实拍摄质量、iOS 正版及会员导出继续注明未验证。
