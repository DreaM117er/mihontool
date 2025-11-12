#!/bin/bash

# --- 配置參數 ---
TARGET_EXT="webp"
PACK_EXT="cbz"
ERROR_LOG="package_errors_$(date +%Y%m%d_%H%M%S).log"
CBZ_OUTPUT_DIR="$PWD" # 保持這個變數，但在主循環中不使用
TEMP_SUCCESS_LOG="temp_success_log_$$"
CHAPTER_FOLDER="chapter_1" # 固定章節資料夾名稱

echo "🚀 開始階段二：CBZ 打包、路徑修正與清理 (簡潔狀態輸出)..." >&2 # 導向 STDERR

# 1. 計算總資料夾數 (只計算包含 chapter_1 資料夾的資料夾)
# 使用 find -exec test 結構，避免多層 shell 引用問題，確保計數準確。
TOTAL_DIRS=$(find . -mindepth 1 -maxdepth 1 -type d -exec test -d "{}/$CHAPTER_FOLDER" \; -print | wc -l)

if [ "$TOTAL_DIRS" -eq 0 ]; then
    echo "未找到任何包含 $CHAPTER_FOLDER 資料夾需要打包的父資料夾。程序結束。" >&2
    # 輸出給 Master Control Script 捕捉：成功資料夾數,錯誤資料夾數,總資料夾數
    echo "0,0,0" | tr -d ' \n\r'
    exit 0
fi

echo "總共找到 $TOTAL_DIRS 個資料夾需要打包。" >&2
echo "錯誤日誌將寫入到 $ERROR_LOG" >&2
echo "--------------------------------------------------" >&2

> "$ERROR_LOG"
> "$TEMP_SUCCESS_LOG"

# --- 核心邏輯：find -print0 | while read 處理特殊字元 ---
# 這是處理特殊字元路徑最穩定的方法

find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' DIR_PATH; do
    
    cbz_name=$(basename "$DIR_PATH")
    CHAPTER_DIR="$DIR_PATH/$CHAPTER_FOLDER"
    
    # --- 關鍵檢查：如果前一個階段失敗，則跳過此資料夾 ---
    if [ -f "$DIR_PATH/.conversion_failed" ]; then
        echo "⛔️ 跳過: $DIR_PATH (轉換階段失敗，無法打包)" >&2
        echo "$DIR_PATH (轉換失敗，已跳過打包)" >> "$ERROR_LOG"
        # 移除標記
        rm "$DIR_PATH/.conversion_failed" 2>/dev/null 
        continue 
    fi
    # ----------------------------------------------------

    # 檢查 chapter_1 資料夾是否存在
    if [ -d "$CHAPTER_DIR" ]; then

        # 1. 封裝 CBZ：將工作目錄切換到 chapter_1，打包內部所有檔案
        # 輸出檔名路徑：從 chapter_1 內部，指向父資料夾 (../chapter_1.cbz)
        CBZ_OUTPUT_REL_PATH="../${CHAPTER_FOLDER}.${PACK_EXT}"
        
        # 進入 chapter_1，打包 *."$TARGET_EXT" 到 ../chapter_1.cbz
        # 這裡使用相對路徑和雙引號，極大提升特殊字元路徑的穩定性
        if (cd "$CHAPTER_DIR" && zip -0 -r "$CBZ_OUTPUT_REL_PATH" *."$TARGET_EXT" 1>&2 2>&1); then
            
            # 2. 清理：刪除 chapter_1 資料夾及其內容 (但保留父資料夾 $DIR_PATH)
            if rm -rf "$CHAPTER_DIR"; then
                # 報告時使用完整的相對路徑
                final_cbz_path="$DIR_PATH/${CHAPTER_FOLDER}.${PACK_EXT}"
                echo "✅ 成功打包並清理: $final_cbz_path (已刪除 $CHAPTER_FOLDER)" >&2
                echo "success" >> "$TEMP_SUCCESS_LOG" # 記錄成功
            else
                echo "⚠️ 清理失敗: 無法刪除 $CHAPTER_DIR (CBZ已創建，請手動刪除 $CHAPTER_FOLDER)。" >> "$ERROR_LOG"
            fi
            
        else
            echo "❌ 打包失敗: $DIR_PATH/$CHAPTER_FOLDER (Zip 錯誤)" >> "$ERROR_LOG"
        fi

    # 由於我們已經在計數時檢查過，這裡的 else 主要是防呆
    else
        echo "➡️ 跳過: $DIR_PATH (未找到 $CHAPTER_FOLDER 資料夾，這不應該發生)" >&2
    fi

done

# --- 最終統計 (僅輸出數據到 STDOUT) ---
SUCCESS_COUNT=$(wc -l < "$TEMP_SUCCESS_LOG")
FAILURE_COUNT=$(wc -l < "$ERROR_LOG")

# 輸出給 Master Control Script 捕捉：成功資料夾數,錯誤資料夾數,總資料夾數
echo "$SUCCESS_COUNT,$FAILURE_COUNT,$TOTAL_DIRS" | tr -d ' \n\r' # 確保輸出只有報告字符串，沒有換行或空白

# 清理臨時檔案
rm "$TEMP_SUCCESS_LOG" 2>/dev/null

if [ "$FAILURE_COUNT" -gt 0 ]; then
    echo "🚨 偵測到 CBZ 打包失敗或跳過 (共 $FAILURE_COUNT 個項目)。請檢查 $ERROR_LOG。" >&2
    exit 1 
fi

exit 0