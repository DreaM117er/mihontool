#!/bin/bash

# --- 配置參數 ---
SOURCE_EXTS="jpg,jpeg,png,bmp,JPG,JPEG,PNG,BMP"
TARGET_EXT="webp"
QUALITY=80
ERROR_LOG="webp_conversion_errors_$(date +%Y%m%d_%H%M%S).log"
TEMP_SUCCESS_LOG="temp_convert_success_log_$$" 

echo "✅ 啟動 WebP 轉換腳本 (簡潔狀態輸出)..." >&2 # 導向 STDERR

# 核心邏輯：構建 Find 參數...
FIND_FILTER_STRING=""
IFS=',' read -r -a extensions <<< "$SOURCE_EXTS"
# 使用 'true'/'false' 字串進行比較，避免語法錯誤
first_ext="true" 
for ext in "${extensions[@]}"; do
    # 修正語法：使用 [ ] 進行字串比較
    if [ "$first_ext" = "false" ]; then 
        FIND_FILTER_STRING="$FIND_FILTER_STRING -o "
    fi
    FIND_FILTER_STRING="$FIND_FILTER_STRING -iname *.$ext"
    first_ext="false"
done

# 1. 計算總檔案數
TOTAL_FILES=$(find . -type f \( $FIND_FILTER_STRING \) | wc -l)

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "未找到任何待轉換的檔案。程序結束。" >&2
    # 輸出給 Master Control Script 捕捉：成功數,失敗數,總數 (0,0,0)
    echo "0,0,0" | tr -d ' \n\r' # 確保輸出只有報告字符串，沒有換行或空白
    exit 0
fi

echo "總共找到 $TOTAL_FILES 個檔案需要檢查和/或轉換。" >&2
echo "錯誤日誌將寫入到 $ERROR_LOG" >&2
echo "--------------------------------------------------" >&2

> "$ERROR_LOG"
> "$TEMP_SUCCESS_LOG"

# --- 核心邏輯：Find + -exec 執行 (所有 echo 皆導向 >&2) ---
# 將所有輸出的 STDOUT/STDERR 都重導向到外部腳本的 STDERR
find . -type f \( $FIND_FILTER_STRING \) -exec sh -c '
    file="$0"
    TARGET_EXT="webp"
    QUALITY=80
    ERROR_LOG="$1"
    TEMP_SUCCESS_LOG="$2"
    target_webp="${file%.*}.${TARGET_EXT}"
    
    # 檢查目標檔案是否已存在
    if [ -f "$target_webp" ]; then
        if [ -f "$file" ]; then rm "$file"; fi
        echo "➡️ 跳過: $file" >&2
        
    else
        # 嘗試轉換
        if convert "$file" -quality "$QUALITY" "$target_webp"; then
            echo "✅ 成功: $file" >&2
            echo "success" >> "$TEMP_SUCCESS_LOG"
            rm "$file"
            
        else
            echo "❌ 失敗: $file (詳見日誌 $ERROR_LOG)" >&2
            echo "$file" >> "$ERROR_LOG"
            DIR_NAME=$(dirname "$file")
            touch "$DIR_NAME/.conversion_failed"
        fi
    fi
' {} "$ERROR_LOG" "$TEMP_SUCCESS_LOG" \;


# --- 最終統計 (僅輸出數據到 STDOUT) ---
SUCCESS_COUNT=$(wc -l < "$TEMP_SUCCESS_LOG")
FAILURE_COUNT=$(wc -l < "$ERROR_LOG")

# 輸出給 Master Control Script 捕捉：成功數,失敗數,總數
echo "$SUCCESS_COUNT,$FAILURE_COUNT,$TOTAL_FILES" | tr -d ' \n\r' # 確保輸出只有報告字符串，沒有換行或空白

# 清理暫存檔案
rm -f "$TEMP_SUCCESS_LOG" 2>/dev/null

if [ "$FAILURE_COUNT" -gt 0 ]; then
    echo "🚨 偵測到轉換失敗 (共 $FAILURE_COUNT 個檔案)。請檢查 $ERROR_LOG。" >&2
    exit 1 
fi

exit 0
