#!/bin/bash

# --- 配置參數 ---
# 設定要處理的圖檔類型 (以空格分隔)
TARGET_EXTENSIONS="jpg jpeg png webp JPG JPEG PNG WEBP"
NEW_NAME_PREFIX="image_" # 新檔名開頭 (例如: image_001.jpg)
DIGIT_COUNT=3          # 編號位數 (例如: 3位數會產生 001, 002...)
ERROR_LOG="errorlog.txt"

echo "---" >&2
echo "執行標準化命名..." >&2
echo "---" >&2

# 尋找所有一級子資料夾
find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' DIR_PATH; do
    
    # --- 1. 檢查並設定信標狀態 ---
    MARKER_PRESENT=""
    NEXT_MARKER=""
    
    if [ -f "$DIR_PATH/m1" ]; then
        MARKER_PRESENT="m1"
        NEXT_MARKER="m2" # m1 (無前綴, 非WEBP) -> 更名 -> m2 (有前綴, 非WEBP)
    elif [ -f "$DIR_PATH/m0" ]; then
        MARKER_PRESENT="m0"
        NEXT_MARKER="m4" # m0 (無前綴, WEBP) -> 更名 -> m4 (有前綴, WEBP)
    else
        # 沒有 m1 或 m0，跳過
        continue
    fi
    
    # 安全檢查：若存在 mi/md 終端信標，則跳過並移除 m1/m0，避免再次處理
    if [ -f "${DIR_PATH}/mi" ] || [ -f "${DIR_PATH}/md" ]; then
        echo "   ✅ 已完成或封裝 ➡️  跳過。" >&2
        rm -f "$DIR_PATH/$MARKER_PRESENT"
        continue 
    fi

    echo "▶️  處理資料夾 $DIR_PATH" >&2

    # --- 2. 準備檔案列表 ---
    count=1
    rename_ok=true
    temp_list=$(mktemp)
    ls_command="ls -v"
    found_files=false
    
    # 構建 ls -v 指令並過濾目標副檔名的檔案
    for ext in $TARGET_EXTENSIONS; do
        if ls "$DIR_PATH"/*.$ext 1> /dev/null 2>&1; then
            ls_command="${ls_command} \"$DIR_PATH\"/*.$ext"
            found_files=true
        fi
    done
    
    if ! $found_files; then
        echo "   ❌ 未找到圖片 ➡️  跳過。" >&2
        rm -f "$temp_list"
        continue
    fi

    # 執行 ls -v（按字母順序排列）並將結果存入臨時文件
    eval "$ls_command" > "$temp_list"

    # --- 3. 執行更名 ---
    while IFS= read -r old_file; do
        # 確保檔案存在且只處理當前目錄下的檔案
        if [ ! -f "$old_file" ] || [[ "$(dirname "$old_file")" != "$DIR_PATH" ]]; then continue; fi

        ext="${old_file##*.}"
        
        # 建立新的檔名 (例如: image_001.jpg)
        format_str="${NEW_NAME_PREFIX}%0${DIGIT_COUNT}d.${ext}"
        new_file_basename=$(printf "$format_str" "$count")
        new_file_path="$DIR_PATH/$new_file_basename"

        # 執行更名
        if ! mv -f "$old_file" "$new_file_path"; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ 資料夾: $DIR_PATH - 檔案: $(basename "$old_file") - 標準化命名失敗。" >> "$ERROR_LOG"
            rename_ok=false
            break
        else
            count=$((count + 1))
        fi
    done < "$temp_list"
    
    rm -f "$temp_list"
    
    # --- 4. 處理信標轉換 ---
    if $rename_ok; then
        SUCCESS_COUNT_IN_DIR=$((count - 1))
        echo "   ✅ 轉換成功，合計 $SUCCESS_COUNT_IN_DIR 個檔案。" >&2
        
        # 信標轉換 (移除舊信標，新增新信標)
        rm -f "$DIR_PATH/$MARKER_PRESENT"
        touch "$DIR_PATH/$NEXT_MARKER"
        echo "---" >&2
    else
        # 更名失敗，直接標記 mf
        echo "   ❌ 資料夾內部有圖片命名失敗，需手動檢查。" >&2
        rm -f "$DIR_PATH/$MARKER_PRESENT"
        touch "${DIR_PATH}/mf"
    fi

done

echo "標準化命名已完成。" >&2

exit 0