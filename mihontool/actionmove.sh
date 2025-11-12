#!/bin/bash

# --- 配置參數 (必須與 forcerename.sh 保持一致) ---
# forcerename.sh 預設為 NEW_NAME_PREFIX="image_" DIGIT_COUNT=3
NEW_NAME_PREFIX="image_" 
DIGIT_COUNT=3          
CHAPTER_FOLDER="chapter_1" # 固定章節資料夾名稱
COVER_NAME="cover"     # 封面圖片名稱 (例如: cover.jpg)
TARGET_EXTENSIONS="jpg jpeg png bmp JPG JPEG PNG BMP" # 允許的圖片副檔名

# 腳本報告及日誌檔
ERROR_LOG="actionmove_errors_$(date +%Y%m%d_%H%M%S).log"
TEMP_SUCCESS_LOG="temp_actionmove_success_log_$$"

# 函數：執行單一資料夾的準備工作 (複製封面/建立章節資料夾/移動)
function process_series_folder() {
local DIR_PATH="$1"
    local prep_ok=true

    # **新增：檢查是否已存在 chapter_1，如果存在則跳過**
    if [ -d "$DIR_PATH/$CHAPTER_FOLDER" ]; then
        echo "➡️ 跳過: $DIR_PATH (chapter_1 已存在，跳過結構建制)" >&2
        return 0
    fi

    # 1. 尋找 forcerename.sh 產生的第一張圖片 (例如 image_001.ext)
    local first_image_path=""
    local found_first_image=false

    # 尋找所有 image_*.ext 檔案 (不限定位數)
    # 注意：這裡依賴 ls -v 的順序，但因為 forcerename.sh 已經保證了編號從 1 開始，
    # 且是該目錄下編號最小的圖片，所以可以尋找 image_1.* 或 image_001.*
    for ext in $TARGET_EXTENSIONS; do
        # 使用 printf -v 確保沒有換行符
        printf -v check_path_padded "$DIR_PATH/%s%0${DIGIT_COUNT}d.$ext" "$NEW_NAME_PREFIX" 1
        
        if [ -f "$check_path_padded" ]; then
            first_image_path="$check_path_padded"
            first_image_ext="${first_image_path##*.}"
            found_first_image=true
            break
        fi
    done

    if ! $found_first_image; then
        echo "➡️ 跳過: $DIR_PATH (未找到 ${NEW_NAME_PREFIX}001.* 圖片，可能已處理或無圖片)" >&2
        return 0
    fi
    
    # 2. 建立章節資料夾，複製封面
    local CHAPTER_DIR="$DIR_PATH/$CHAPTER_FOLDER"
    mkdir -p "$CHAPTER_DIR"
    
    # 複製第一張圖為封面 (在根目錄)
    local COVER_PATH="$DIR_PATH/$COVER_NAME.$first_image_ext"
    if cp -f "$first_image_path" "$COVER_PATH"; then
        echo "✅ 複製封面: $COVER_PATH" >&2
    else
        echo "❌ 錯誤：複製封面 $first_image_path 失敗。" >> "$ERROR_LOG"
        prep_ok=false
    fi

    # 3. 移動所有圖片到章節資料夾 (除了封面副本)
    local moved_count=0
    
    # 尋找所有 'image_*.ext' 檔案，排除封面副本
    local image_files=$(find "$DIR_PATH" -maxdepth 1 -type f -name "${NEW_NAME_PREFIX}*.*" -print0 | tr '\0' '\n' | grep -v "$COVER_NAME.$first_image_ext") 

    echo "$image_files" | while IFS= read -r IMAGE_FILE; do
        if [ -n "$IMAGE_FILE" ] && [ -f "$IMAGE_FILE" ]; then
            if mv -f "$IMAGE_FILE" "$CHAPTER_DIR/"; then
                moved_count=$((moved_count + 1))
            else
                echo "❌ 錯誤：移動 $IMAGE_FILE 到 $CHAPTER_DIR 失敗。" >> "$ERROR_LOG"
                prep_ok=false
            fi
        fi
    done

    if $prep_ok; then
        echo "✅ 成功: $DIR_PATH (建立 $CHAPTER_FOLDER 結構，移動 $moved_count 張圖片)" >&2
        echo "success" >> "$TEMP_SUCCESS_LOG"
        return 0
    else
        echo "❌ 失敗: $DIR_PATH (移動/複製階段出錯)" >&2
        echo "$DIR_PATH (移動/複製階段出錯)" >> "$ERROR_LOG"
        return 1
    fi
}

# --- 主要執行邏輯 (批次處理) ---
echo "📖 開始執行批次漫畫結構準備 (封面/Chapter_01 資料夾/移動)..." >&2
echo "錯誤日誌將寫入到 $ERROR_LOG" >&2
echo "------------------------------------------------------------------" >&2

> "$ERROR_LOG"
> "$TEMP_SUCCESS_LOG"

# 尋找所有一級子資料夾
find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' DIR_PATH; do
    process_series_folder "$DIR_PATH"
done

# --- 最終統計 (輸出報告給 Master) ---
SUCCESS_COUNT=$(wc -l < "$TEMP_SUCCESS_LOG" 2>/dev/null)
FAILURE_COUNT=$(wc -l < "$ERROR_LOG" 2>/dev/null)
TOTAL_DIRS=$(($SUCCESS_COUNT + $FAILURE_COUNT))

if [ -f "$TEMP_SUCCESS_LOG" ]; then rm "$TEMP_SUCCESS_LOG"; fi

# 輸出給 Master Control Script 捕捉：成功目錄數, 錯誤目錄數, 總目錄數
echo "$SUCCESS_COUNT,$FAILURE_COUNT,$TOTAL_DIRS" | tr -d ' \n\r'
exit 0