#!/bin/bash

# --- 配置參數 (可依需求調整) ---
# 設定要處理的圖檔類型 (以空格分隔)
TARGET_EXTENSIONS="jpg jpeg png webp JPG JPEG PNG WEBP"
NEW_NAME_PREFIX="image_" # 新檔名開頭 (例如: page_001.jpg)
DIGIT_COUNT=3          # 編號位數 (例如: 3位數會產生 001, 002...)

# 腳本報告及日誌檔 (與 rename.sh 結構相似)
ERROR_LOG="force_rename_errors_$(date +%Y%m%d_%H%M%S).log"
TEMP_SUCCESS_LOG="temp_force_rename_success_log_$$"

echo "🚀 開始階段一：多圖檔類型、順序命名規範化 (遞迴執行)..." >&2
echo "錯誤日誌將寫入到 $ERROR_LOG" >&2
echo "--------------------------------------------------" >&2

> "$ERROR_LOG"
> "$TEMP_SUCCESS_LOG"

# --- 核心邏輯：Find + -exec 執行 (所有 echo 皆導向 >&2) ---
# 尋找所有子資料夾 (排除當前目錄 .)，並對每個資料夾執行更名操作
find . -mindepth 1 -type d -exec sh -c '
    DIR_PATH="$0"
    ERROR_LOG="$1"
    TEMP_SUCCESS_LOG="$2"
    
    # 內建配置 (從外部繼承)
    TARGET_EXTENSIONS="'"$TARGET_EXTENSIONS"'" 
    NEW_NAME_PREFIX="'"$NEW_NAME_PREFIX"'"
    DIGIT_COUNT="'"$DIGIT_COUNT"'"
    
    count=1
    rename_ok=true
    temp_list=$(mktemp)
    
    # 1. 構建 ls -v 指令並過濾檔案
    ls_command="ls -v"
    found_files=false
    
    # 檢查該目錄下是否有符合目標副檔名的檔案
    for ext in $TARGET_EXTENSIONS; do
        if ls "$DIR_PATH"/*.$ext 1> /dev/null 2>&1; then
            # 找到符合的檔案，將其加入 ls 列表
            ls_command="${ls_command} \"$DIR_PATH\"/*.$ext"
            found_files=true
        fi
    done
    
    # 如果沒有找到任何圖片，則跳過此目錄
    if ! $found_files; then
        return 0
    fi

    # 執行 ls -v 並將結果存入臨時文件，以確保正確的自然排序
    eval "$ls_command" > "$temp_list"

    # 2. 讀取列表並更名
    while IFS= read -r old_file; do
        if [ ! -f "$old_file" ]; then continue; fi

        # 獲取檔案副檔名
        ext="${old_file##*.}"
        
        # 產生新的檔名 (例如: page_001.jpg)
        format_str="${NEW_NAME_PREFIX}%0${DIGIT_COUNT}d.${ext}"
        new_file_basename=$(printf "$format_str" "$count")
        
        # 完整的目標路徑
        new_file_path="$DIR_PATH/$new_file_basename"

        # 執行更名
        if ! mv -f "$old_file" "$new_file_path"; then
            # --- 更名失敗，記錄並中斷目錄處理 ---
            echo "$old_file (更名失敗)" >> "$ERROR_LOG"
            rename_ok=false
            echo "⚠️ 錯誤中斷: $DIR_PATH (檔案 $old_file 更名失敗，停止後續操作)" >&2
            echo "$DIR_PATH (更名中斷)" >> "$ERROR_LOG"
            break
            # -------------------------------------
        else
            count=$((count + 1))
        fi
    done < "$temp_list"
    
    # 3. 清理臨時檔案
    rm -f "$temp_list" 2>/dev/null
    
    if $rename_ok; then
        echo "✅ 成功: $DIR_PATH (更名 $((count - 1)) 個檔案)" >&2
        echo "success" >> "$TEMP_SUCCESS_LOG" # 記錄成功更名的目錄路徑
    fi
' {} "$ERROR_LOG" "$TEMP_SUCCESS_LOG" \;

# --- 最終統計 (僅輸出數據到 STDOUT，格式為 成功數,失敗數,總數) ---
SUCCESS_COUNT=$(grep -c "success" "$TEMP_SUCCESS_LOG")
FAILURE_COUNT=$(grep -c "更名中斷" "$ERROR_LOG")
TOTAL_DIRS=$(find . -mindepth 1 -type d | wc -l)

# 輸出給 Master Control Script 捕捉
echo "$SUCCESS_COUNT,$FAILURE_COUNT,$TOTAL_DIRS" | tr -d ' \n\r'

echo "--------------------------------------------------" >&2
echo "🎉 批次命名完成：成功資料夾 $SUCCESS_COUNT 個，錯誤資料夾 $FAILURE_COUNT 個。" >&2
