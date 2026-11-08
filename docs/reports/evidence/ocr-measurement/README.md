# OCR 原始证据

测量日期：2026-11-07。环境：Xcode 27.2 / iPhone 18 Pro / iOS 27.0。

每条记录包含当次 Vision 输出、初始解析结果、检测四角、原图哈希和实际识别输入图片。

[运行元数据](run.json)；[完整识别记录](recognition-records.json)；[字段统计](metrics.csv)。

图片坐标采用归一化值，原点位于左上角；四角顺序为左上、右上、右下、左下。

逐行文字保留 Vision 第一候选结果；rawText 由 VisionTextRecognizer 按纵向位置排序后拼接。

人工修改记录和正版观察结果由使用者填写在提交模板中。

| 原始图片 | OCR 原文 | 初始解析 | 实际识别输入 |
|---|---|---|---|
| [zh-01.png](../../../../TestData/cards/zh-01.png) | [文字](raw-text/zh-01.png.txt) | [字段与依据](parsed/zh-01.png.json) | [图片](images/processed-zh-01.png) |
| [zh-01-occluded.png](../../../../TestData/cards/zh-01-occluded.png) | [文字](raw-text/zh-01-occluded.png.txt) | [字段与依据](parsed/zh-01-occluded.png.json) | [图片](images/processed-zh-01-occluded.png) |
| [zh-01-photo.jpg](../../../../TestData/cards/zh-01-photo.jpg) | [文字](raw-text/zh-01-photo.jpg.txt) | [字段与依据](parsed/zh-01-photo.jpg.json) | [图片](images/processed-zh-01-photo.png) |
| [zh-01-photo-occluded.jpg](../../../../TestData/cards/zh-01-photo-occluded.jpg) | [文字](raw-text/zh-01-photo-occluded.jpg.txt) | [字段与依据](parsed/zh-01-photo-occluded.jpg.json) | [图片](images/processed-zh-01-photo-occluded.png) |
| [zh-02.png](../../../../TestData/cards/zh-02.png) | [文字](raw-text/zh-02.png.txt) | [字段与依据](parsed/zh-02.png.json) | [图片](images/processed-zh-02.png) |
| [zh-03.png](../../../../TestData/cards/zh-03.png) | [文字](raw-text/zh-03.png.txt) | [字段与依据](parsed/zh-03.png.json) | [图片](images/processed-zh-03.png) |
| [zh-04.png](../../../../TestData/cards/zh-04.png) | [文字](raw-text/zh-04.png.txt) | [字段与依据](parsed/zh-04.png.json) | [图片](images/processed-zh-04.png) |
| [zh-05.png](../../../../TestData/cards/zh-05.png) | [文字](raw-text/zh-05.png.txt) | [字段与依据](parsed/zh-05.png.json) | [图片](images/processed-zh-05.png) |
| [zh-05-occluded.png](../../../../TestData/cards/zh-05-occluded.png) | [文字](raw-text/zh-05-occluded.png.txt) | [字段与依据](parsed/zh-05-occluded.png.json) | [图片](images/processed-zh-05-occluded.png) |
| [zh-05-photo.jpg](../../../../TestData/cards/zh-05-photo.jpg) | [文字](raw-text/zh-05-photo.jpg.txt) | [字段与依据](parsed/zh-05-photo.jpg.json) | [图片](images/processed-zh-05-photo.png) |
| [zh-05-photo-occluded.jpg](../../../../TestData/cards/zh-05-photo-occluded.jpg) | [文字](raw-text/zh-05-photo-occluded.jpg.txt) | [字段与依据](parsed/zh-05-photo-occluded.jpg.json) | [图片](images/processed-zh-05-photo-occluded.png) |
| [zh-06.png](../../../../TestData/cards/zh-06.png) | [文字](raw-text/zh-06.png.txt) | [字段与依据](parsed/zh-06.png.json) | [图片](images/processed-zh-06.png) |
| [zh-07.png](../../../../TestData/cards/zh-07.png) | [文字](raw-text/zh-07.png.txt) | [字段与依据](parsed/zh-07.png.json) | [图片](images/processed-zh-07.png) |
| [zh-08.png](../../../../TestData/cards/zh-08.png) | [文字](raw-text/zh-08.png.txt) | [字段与依据](parsed/zh-08.png.json) | [图片](images/processed-zh-08.png) |
| [zh-09.png](../../../../TestData/cards/zh-09.png) | [文字](raw-text/zh-09.png.txt) | [字段与依据](parsed/zh-09.png.json) | [图片](images/processed-zh-09.png) |
| [zh-09-occluded.png](../../../../TestData/cards/zh-09-occluded.png) | [文字](raw-text/zh-09-occluded.png.txt) | [字段与依据](parsed/zh-09-occluded.png.json) | [图片](images/processed-zh-09-occluded.png) |
| [zh-09-photo.jpg](../../../../TestData/cards/zh-09-photo.jpg) | [文字](raw-text/zh-09-photo.jpg.txt) | [字段与依据](parsed/zh-09-photo.jpg.json) | [图片](images/processed-zh-09-photo.png) |
| [zh-09-photo-occluded.jpg](../../../../TestData/cards/zh-09-photo-occluded.jpg) | [文字](raw-text/zh-09-photo-occluded.jpg.txt) | [字段与依据](parsed/zh-09-photo-occluded.jpg.json) | [图片](images/processed-zh-09-photo-occluded.png) |
| [zh-10.png](../../../../TestData/cards/zh-10.png) | [文字](raw-text/zh-10.png.txt) | [字段与依据](parsed/zh-10.png.json) | [图片](images/processed-zh-10.png) |
| [zh-11.png](../../../../TestData/cards/zh-11.png) | [文字](raw-text/zh-11.png.txt) | [字段与依据](parsed/zh-11.png.json) | [图片](images/processed-zh-11.png) |
| [zh-12.png](../../../../TestData/cards/zh-12.png) | [文字](raw-text/zh-12.png.txt) | [字段与依据](parsed/zh-12.png.json) | [图片](images/processed-zh-12.png) |
| [zh-12-occluded.png](../../../../TestData/cards/zh-12-occluded.png) | [文字](raw-text/zh-12-occluded.png.txt) | [字段与依据](parsed/zh-12-occluded.png.json) | [图片](images/processed-zh-12-occluded.png) |
| [zh-13.png](../../../../TestData/cards/zh-13.png) | [文字](raw-text/zh-13.png.txt) | [字段与依据](parsed/zh-13.png.json) | [图片](images/processed-zh-13.png) |
| [zh-13-photo.jpg](../../../../TestData/cards/zh-13-photo.jpg) | [文字](raw-text/zh-13-photo.jpg.txt) | [字段与依据](parsed/zh-13-photo.jpg.json) | [图片](images/processed-zh-13-photo.png) |
| [zh-14.png](../../../../TestData/cards/zh-14.png) | [文字](raw-text/zh-14.png.txt) | [字段与依据](parsed/zh-14.png.json) | [图片](images/processed-zh-14.png) |
| [zh-15.png](../../../../TestData/cards/zh-15.png) | [文字](raw-text/zh-15.png.txt) | [字段与依据](parsed/zh-15.png.json) | [图片](images/processed-zh-15.png) |
| [en-01.png](../../../../TestData/cards/en-01.png) | [文字](raw-text/en-01.png.txt) | [字段与依据](parsed/en-01.png.json) | [图片](images/processed-en-01.png) |
| [en-02.png](../../../../TestData/cards/en-02.png) | [文字](raw-text/en-02.png.txt) | [字段与依据](parsed/en-02.png.json) | [图片](images/processed-en-02.png) |
| [en-02-occluded.png](../../../../TestData/cards/en-02-occluded.png) | [文字](raw-text/en-02-occluded.png.txt) | [字段与依据](parsed/en-02-occluded.png.json) | [图片](images/processed-en-02-occluded.png) |
| [en-03.png](../../../../TestData/cards/en-03.png) | [文字](raw-text/en-03.png.txt) | [字段与依据](parsed/en-03.png.json) | [图片](images/processed-en-03.png) |
| [en-03-photo.jpg](../../../../TestData/cards/en-03-photo.jpg) | [文字](raw-text/en-03-photo.jpg.txt) | [字段与依据](parsed/en-03-photo.jpg.json) | [图片](images/processed-en-03-photo.png) |
| [en-04.png](../../../../TestData/cards/en-04.png) | [文字](raw-text/en-04.png.txt) | [字段与依据](parsed/en-04.png.json) | [图片](images/processed-en-04.png) |
| [en-05.png](../../../../TestData/cards/en-05.png) | [文字](raw-text/en-05.png.txt) | [字段与依据](parsed/en-05.png.json) | [图片](images/processed-en-05.png) |
| [en-06.png](../../../../TestData/cards/en-06.png) | [文字](raw-text/en-06.png.txt) | [字段与依据](parsed/en-06.png.json) | [图片](images/processed-en-06.png) |
| [en-06-occluded.png](../../../../TestData/cards/en-06-occluded.png) | [文字](raw-text/en-06-occluded.png.txt) | [字段与依据](parsed/en-06-occluded.png.json) | [图片](images/processed-en-06-occluded.png) |
| [en-07.png](../../../../TestData/cards/en-07.png) | [文字](raw-text/en-07.png.txt) | [字段与依据](parsed/en-07.png.json) | [图片](images/processed-en-07.png) |
| [en-08.png](../../../../TestData/cards/en-08.png) | [文字](raw-text/en-08.png.txt) | [字段与依据](parsed/en-08.png.json) | [图片](images/processed-en-08.png) |
| [en-08-photo.jpg](../../../../TestData/cards/en-08-photo.jpg) | [文字](raw-text/en-08-photo.jpg.txt) | [字段与依据](parsed/en-08-photo.jpg.json) | [图片](images/processed-en-08-photo.png) |
| [en-09.png](../../../../TestData/cards/en-09.png) | [文字](raw-text/en-09.png.txt) | [字段与依据](parsed/en-09.png.json) | [图片](images/processed-en-09.png) |
| [en-10.png](../../../../TestData/cards/en-10.png) | [文字](raw-text/en-10.png.txt) | [字段与依据](parsed/en-10.png.json) | [图片](images/processed-en-10.png) |
| [en-11.png](../../../../TestData/cards/en-11.png) | [文字](raw-text/en-11.png.txt) | [字段与依据](parsed/en-11.png.json) | [图片](images/processed-en-11.png) |
| [en-11-occluded.png](../../../../TestData/cards/en-11-occluded.png) | [文字](raw-text/en-11-occluded.png.txt) | [字段与依据](parsed/en-11-occluded.png.json) | [图片](images/processed-en-11-occluded.png) |
| [en-12.png](../../../../TestData/cards/en-12.png) | [文字](raw-text/en-12.png.txt) | [字段与依据](parsed/en-12.png.json) | [图片](images/processed-en-12.png) |
| [en-13.png](../../../../TestData/cards/en-13.png) | [文字](raw-text/en-13.png.txt) | [字段与依据](parsed/en-13.png.json) | [图片](images/processed-en-13.png) |
| [en-13-photo.jpg](../../../../TestData/cards/en-13-photo.jpg) | [文字](raw-text/en-13-photo.jpg.txt) | [字段与依据](parsed/en-13-photo.jpg.json) | [图片](images/processed-en-13-photo.png) |
| [en-14.png](../../../../TestData/cards/en-14.png) | [文字](raw-text/en-14.png.txt) | [字段与依据](parsed/en-14.png.json) | [图片](images/processed-en-14.png) |
| [en-15.png](../../../../TestData/cards/en-15.png) | [文字](raw-text/en-15.png.txt) | [字段与依据](parsed/en-15.png.json) | [图片](images/processed-en-15.png) |
| [bi-01.png](../../../../TestData/cards/bi-01.png) | [文字](raw-text/bi-01.png.txt) | [字段与依据](parsed/bi-01.png.json) | [图片](images/processed-bi-01.png) |
| [bi-02.png](../../../../TestData/cards/bi-02.png) | [文字](raw-text/bi-02.png.txt) | [字段与依据](parsed/bi-02.png.json) | [图片](images/processed-bi-02.png) |
| [bi-02-photo.jpg](../../../../TestData/cards/bi-02-photo.jpg) | [文字](raw-text/bi-02-photo.jpg.txt) | [字段与依据](parsed/bi-02-photo.jpg.json) | [图片](images/processed-bi-02-photo.png) |
| [bi-03.png](../../../../TestData/cards/bi-03.png) | [文字](raw-text/bi-03.png.txt) | [字段与依据](parsed/bi-03.png.json) | [图片](images/processed-bi-03.png) |
| [bi-03-occluded.png](../../../../TestData/cards/bi-03-occluded.png) | [文字](raw-text/bi-03-occluded.png.txt) | [字段与依据](parsed/bi-03-occluded.png.json) | [图片](images/processed-bi-03-occluded.png) |
| [bi-04.png](../../../../TestData/cards/bi-04.png) | [文字](raw-text/bi-04.png.txt) | [字段与依据](parsed/bi-04.png.json) | [图片](images/processed-bi-04.png) |
| [bi-05.png](../../../../TestData/cards/bi-05.png) | [文字](raw-text/bi-05.png.txt) | [字段与依据](parsed/bi-05.png.json) | [图片](images/processed-bi-05.png) |
| [bi-06.png](../../../../TestData/cards/bi-06.png) | [文字](raw-text/bi-06.png.txt) | [字段与依据](parsed/bi-06.png.json) | [图片](images/processed-bi-06.png) |
| [bi-06-photo.jpg](../../../../TestData/cards/bi-06-photo.jpg) | [文字](raw-text/bi-06-photo.jpg.txt) | [字段与依据](parsed/bi-06-photo.jpg.json) | [图片](images/processed-bi-06-photo.png) |
| [bi-07.png](../../../../TestData/cards/bi-07.png) | [文字](raw-text/bi-07.png.txt) | [字段与依据](parsed/bi-07.png.json) | [图片](images/processed-bi-07.png) |
| [bi-08.png](../../../../TestData/cards/bi-08.png) | [文字](raw-text/bi-08.png.txt) | [字段与依据](parsed/bi-08.png.json) | [图片](images/processed-bi-08.png) |
| [bi-08-occluded.png](../../../../TestData/cards/bi-08-occluded.png) | [文字](raw-text/bi-08-occluded.png.txt) | [字段与依据](parsed/bi-08-occluded.png.json) | [图片](images/processed-bi-08-occluded.png) |
| [bi-09.png](../../../../TestData/cards/bi-09.png) | [文字](raw-text/bi-09.png.txt) | [字段与依据](parsed/bi-09.png.json) | [图片](images/processed-bi-09.png) |
| [bi-10.png](../../../../TestData/cards/bi-10.png) | [文字](raw-text/bi-10.png.txt) | [字段与依据](parsed/bi-10.png.json) | [图片](images/processed-bi-10.png) |
| [bi-10-photo.jpg](../../../../TestData/cards/bi-10-photo.jpg) | [文字](raw-text/bi-10-photo.jpg.txt) | [字段与依据](parsed/bi-10-photo.jpg.json) | [图片](images/processed-bi-10-photo.png) |
| [bi-11.png](../../../../TestData/cards/bi-11.png) | [文字](raw-text/bi-11.png.txt) | [字段与依据](parsed/bi-11.png.json) | [图片](images/processed-bi-11.png) |
| [bi-12.png](../../../../TestData/cards/bi-12.png) | [文字](raw-text/bi-12.png.txt) | [字段与依据](parsed/bi-12.png.json) | [图片](images/processed-bi-12.png) |
| [bi-13.png](../../../../TestData/cards/bi-13.png) | [文字](raw-text/bi-13.png.txt) | [字段与依据](parsed/bi-13.png.json) | [图片](images/processed-bi-13.png) |
| [bi-14.png](../../../../TestData/cards/bi-14.png) | [文字](raw-text/bi-14.png.txt) | [字段与依据](parsed/bi-14.png.json) | [图片](images/processed-bi-14.png) |
| [bi-14-occluded.png](../../../../TestData/cards/bi-14-occluded.png) | [文字](raw-text/bi-14-occluded.png.txt) | [字段与依据](parsed/bi-14-occluded.png.json) | [图片](images/processed-bi-14-occluded.png) |
| [bi-14-photo.jpg](../../../../TestData/cards/bi-14-photo.jpg) | [文字](raw-text/bi-14-photo.jpg.txt) | [字段与依据](parsed/bi-14-photo.jpg.json) | [图片](images/processed-bi-14-photo.png) |
| [bi-14-photo-occluded.jpg](../../../../TestData/cards/bi-14-photo-occluded.jpg) | [文字](raw-text/bi-14-photo-occluded.jpg.txt) | [字段与依据](parsed/bi-14-photo-occluded.jpg.json) | [图片](images/processed-bi-14-photo-occluded.png) |
| [bi-15.png](../../../../TestData/cards/bi-15.png) | [文字](raw-text/bi-15.png.txt) | [字段与依据](parsed/bi-15.png.json) | [图片](images/processed-bi-15.png) |
| [bi-16.png](../../../../TestData/cards/bi-16.png) | [文字](raw-text/bi-16.png.txt) | [字段与依据](parsed/bi-16.png.json) | [图片](images/processed-bi-16.png) |
| [bi-17.png](../../../../TestData/cards/bi-17.png) | [文字](raw-text/bi-17.png.txt) | [字段与依据](parsed/bi-17.png.json) | [图片](images/processed-bi-17.png) |
| [bi-18.png](../../../../TestData/cards/bi-18.png) | [文字](raw-text/bi-18.png.txt) | [字段与依据](parsed/bi-18.png.json) | [图片](images/processed-bi-18.png) |
| [bi-18-photo.jpg](../../../../TestData/cards/bi-18-photo.jpg) | [文字](raw-text/bi-18-photo.jpg.txt) | [字段与依据](parsed/bi-18-photo.jpg.json) | [图片](images/processed-bi-18-photo.png) |
| [bi-19.png](../../../../TestData/cards/bi-19.png) | [文字](raw-text/bi-19.png.txt) | [字段与依据](parsed/bi-19.png.json) | [图片](images/processed-bi-19.png) |
| [bi-20.png](../../../../TestData/cards/bi-20.png) | [文字](raw-text/bi-20.png.txt) | [字段与依据](parsed/bi-20.png.json) | [图片](images/processed-bi-20.png) |
