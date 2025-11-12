# mihontool

## 說明

這是基於開源漫畫軟體 Mihon 所建制的一個 Linux 終端執行的 Shell 腳本工具集，可以用於以下條件：
1. 下載下來的漫畫資料夾檔案。
2. 統一任意格式成 .webp。
3. 依照 Mihon 文本說明裡的 [Local Source](https://mihon.app/docs/guides/local-source/#folder-structure) 建制資料夾架構。

## 注意事項

1. 重要：請勿用來做非法用途，不鼓勵任何侵犯著作權之行爲。
2. 提供 Shell 腳本及使用方式，歡迎你做任何的修正修改。

## 架構及邏輯

![](pic/001.png) ![](pic/002.png)

根據 Mihon 文本說明中的 [Local Source](https://mihon.app/docs/guides/local-source/#folder-structure) 裡的架構圖我們可以得知幾個方案：

### 腳本邏輯

- **方案A：基於該漫畫有幾個章節來做區分**
    1. 排序圖片檔案及重新命名，以 001.ext、002.ext 做區分。
    2. 定義章節數量，chapter_1、chapter_2、chapter_n......。
    3. 定義每個章節裡的圖片範圍，將 001.ext-012.ext 移入 chapter_1 的資料夾。
    4. 定義 cover.ext 作爲漫畫封面，若沒定義則預設 001.ext 爲封面。
    6. 轉換內部的圖片檔案爲 webp。
    7. 重新排序整個架構裡的圖片排序。
    8. 封裝成 .cbz 檔案。

- **執行結果：**
    1. 重複執行排序及命名，腳本架構過於複雜。
    2. 互動式架構會需要做手動選擇範圍及定義，無法批量處理。
    3. 漫畫類型有分單行本、同仁本、畫集，無法完美適用。

    我請 AI 放棄這個腳本架構，重新建立一個B方案。

- **方案B：基於單一Chapter_1架構區分**
    1. 排序圖片檔案及重新命名，以 image_001.ext、image_002.ext 做區分。
    2. 新增一個 Chapter_1 資料夾作爲主架構，將 image_n.ext 移動到內部。
    3. 因爲電子檔漫畫多半以第 1 張圖片爲封面，因此將 image_001.ext 作爲漫畫封面使用（cover.ext）。
    4. 轉換內部的圖片檔案爲 webp。
    5. 選擇性封裝 chapter_1 資料夾爲 .cbz

- **執行結果：**
    1. 命名僅執行1次、轉換檔案1次、封裝1次、調整架構1次。
    2. 效率提升，可以批量處理。
    3. 任何單行本、同仁本、畫集都可以處理。
    4. 簡化架構，chapter_2 之後的章節都很好處理，但需要手動變更chapter_n。

## 腳本架構（方案B）

|腳本(.sh)|主要功能|執行項目|
|--|--|--|
|forcerename|重新命名及排序|image_001.ext, image_002.ext, image_n.ext 排序|
|actionmove|移動檔案及調整架構|將 image_n.ext 移入 chapter_1 及定義 image_001.ext 作爲 cover.ext使用|
|auto_convert|轉換檔案格式|將任意圖片檔案轉換爲 webp 格式|
|pack_cbz|封裝 chapter_1.cbz|封裝完畢之後移除 chapter_1 資料夾|
|master_control|控制台|統合流程及報告產出|