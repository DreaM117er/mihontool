#!/bin/bash

# --- 配置參數 ---
TARGET_EXT="webp"
PACK_EXT="cbz"
ERROR_LOG="packcbz-error-$(date +%Y%m%d%H%M%S).log"
CBZ_OUTPUT_DIR="$PWD" 
TEMP_SUCCESS_LOG="temp_success_log_$$"
CHAPTER_FOLDER="chapter_1" # 固定章節資料夾名稱

echo "---" >&2
echo "執行結構主體 chapter_1 的封裝 (.cbz) ..." >&2 # 導向 STDERR

# 1. 計算總資料夾數 (只計算包含 mi 信標的資料夾)
TOTAL_DIRS=$(find . -mindepth 1 -maxdepth 1 -type d -exec test -f "{}/mi" \; -print | wc -l)

if [ "$TOTAL_DIRS" -eq 0 ]; then
    echo "未找到任何帶有 chapter_1 資料夾的需要封裝，腳本執行完畢。" >&2
    # 移除底部的資料捕捉數字輸出
    exit 0
fi

echo "總共有 $TOTAL_DIRS 個資料夾需要封裝。" >&2
echo "---" >&2

> "$ERROR_LOG"
> "$TEMP_SUCCESS_LOG"

# --- 核心邏輯：find -print0 | while read 處理特殊字元 ---

find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' DIR_PATH; do
    
    cbz_name=$(basename "$DIR_PATH")
    CHAPTER_DIR="$DIR_PATH/$CHAPTER_FOLDER"
    
    # --- 關鍵檢查：只處理有 mi 信標的資料夾 ---
    if [ ! -f "$DIR_PATH/mi" ]; then
        continue # 沒有 mi 信標，跳過。
    fi
    
    # --- 安全檢查：如果已經有 md 信標，表示已是 CBZ 格式，跳過 ---
    if [ -f "$DIR_PATH/md" ]; then
        echo "➡️ 已有 cbz 封裝，跳過。" >&2
        # 可選擇移除 mi，讓下一次 markdown.sh 統一處理
        [ -f "$DIR_PATH/mi" ] && rm "$DIR_PATH/mi"
        continue
    fi
    # ----------------------------------------------------
    
    # 檢查 chapter_1 資料夾是否存在 (mi 標記的前提就是 chapter_1 存在)
    if [ -d "$CHAPTER_DIR" ]; then

        # 1. 封裝 CBZ：將工作目錄切換到 chapter_1，打包內部所有檔案
        CBZ_OUTPUT_REL_PATH="../${CHAPTER_FOLDER}.${PACK_EXT}"
        
        echo "▶️  正在封裝 $CHAPTER_DIR" >&2

        # 核心變動點 1：將 zip 的 stdout 和 stderr 都導向 /dev/null
        if (cd "$CHAPTER_DIR" && zip -0 -r "$CBZ_OUTPUT_REL_PATH" *."$TARGET_EXT" > /dev/null 2>&1); then
            
            # 2. 清理：刪除 chapter_1 資料夾及其內容
            if rm -rf "$CHAPTER_DIR"; then
                final_cbz_path="$DIR_PATH/${CHAPTER_FOLDER}.${PACK_EXT}"
                echo "   ✅ 封裝成功，已刪除 $CHAPTER_FOLDER 資料夾" >&2
                echo "success" >> "$TEMP_SUCCESS_LOG" # 記錄成功
                
                # 3. 清除信標：移除 mi 信標並新增 md
                if [ -f "$DIR_PATH/mi" ]; then
                    rm "$DIR_PATH/mi"
                    touch "$DIR_PATH/md" # <<<--- 新增 md 標記
                    echo "   ✅ 結構封裝已完成。" >&2
                    echo "---" >&2
                fi
                
            else
                echo "   ⚠️ 封裝完成，需手動刪除 $CHAPTER_FOLDER)。" >> "$ERROR_LOG"
            fi
            
        else
            echo "   ❌ 封裝失敗: $DIR_PATH/$CHAPTER_FOLDER (Zip 錯誤)" >> "$ERROR_LOG"
            rm "$DIR_PATH/mi"
            touch "$DIR_PATH/mf"
        fi

    else
        # mi 標記存在但 chapter_1 不存在，結構異常
        echo "   ❌ 資料夾內未找到 $CHAPTER_FOLDER，結構異常 ➡️ 跳過。" >&2
        rm "$DIR_PATH/mi"
        rm "$DIR_PATH/mf"
    fi

done

# --- 最終統計 (移除資料捕捉數字輸出) ---
SUCCESS_COUNT=$(wc -l < "$TEMP_SUCCESS_LOG")
FAILURE_COUNT=$(wc -l < "$ERROR_LOG")

# 移除輸出給 Master Control Script 捕捉的行
# echo "$SUCCESS_COUNT,$FAILURE_COUNT,$TOTAL_DIRS" | tr -d ' \n\r' 

# 清理臨時檔案
rm "$TEMP_SUCCESS_LOG" 2>/dev/null

if [ "$FAILURE_COUNT" -gt 0 ]; then
    echo "🚨 CBZ 封裝失敗 (共 $FAILURE_COUNT 個項目)。請檢查 $ERROR_LOG。" >&2
    exit 1 
fi

echo "資料夾封裝作業已全數完成。" >&2
echo "錯誤日誌將寫入到 $ERROR_LOG" >&2

exit 0