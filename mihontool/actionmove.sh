#!/bin/bash

# --- 配置參數 ---
# 必須與 forcerename.sh 保持一致
NEW_NAME_PREFIX="image_" 
DIGIT_COUNT=3          
CHAPTER_FOLDER="chapter_1" # 固定章節資料夾名稱
COVER_NAME="cover"     # 封面圖片名稱 (例如: cover.jpg)
TARGET_EXTENSIONS="jpg jpeg png bmp webp JPG JPEG PNG BMP WEBP" # 允許的圖片副檔名

echo "---" >&2
echo "執行及建立 Mihon 漫畫結構目錄主體..." >&2
echo "---" >&2

# 函數：執行單一資料夾的準備工作 (複製封面/建立章節資料夾/移動)
function process_series_folder() {
    local DIR_PATH="$1"
    local prep_ok=true

    # **檢查是否已存在 chapter_1，如果存在則跳過**
    if [ -d "$DIR_PATH/$CHAPTER_FOLDER" ]; then
        echo "   ✅ chapter_1 已存在 ➡️  跳過。" >&2
        return 0 # 返回 0 視為成功/跳過
    fi

    # 1. 尋找 forcerename.sh 產生的第一張圖片 (例如 image_001.ext)
    local first_image_path=""
    local first_image_ext=""
    local found_first_image=false

    for ext in $TARGET_EXTENSIONS; do
        printf -v check_path_padded "$DIR_PATH/%s%0${DIGIT_COUNT}d.$ext" "$NEW_NAME_PREFIX" 1
        
        if [ -f "$check_path_padded" ]; then
            first_image_path="$check_path_padded"
            first_image_ext="${first_image_path##*.}"
            found_first_image=true
            break
        fi
    done

    if ! $found_first_image; then
        echo "   ❌ 找不到 ${NEW_NAME_PREFIX}001.* 圖片 ➡️ 跳過。" >&2
        return 1 # 找不到圖片，視為處理失敗
    fi
    
    # 【新增邏輯 A】：計算總圖片數 (預期移動數)
    TOTAL_IMAGE_COUNT=$(find "$DIR_PATH" -maxdepth 1 -type f -name "${NEW_NAME_PREFIX}*.*" | wc -l)
    echo "   🔎 合計有 $TOTAL_IMAGE_COUNT 張漫畫圖片。" >&2
    
    if [ "$TOTAL_IMAGE_COUNT" -eq 0 ]; then
        echo "   ❌ 資料夾內無圖片 ➡️  跳過。" >&2
        return 1
    fi

    # 2. 建立章節資料夾，複製封面
    local CHAPTER_DIR="$DIR_PATH/$CHAPTER_FOLDER"
    mkdir -p "$CHAPTER_DIR"
    
    # 複製第一張圖為封面 (在根目錄)
    local COVER_PATH="$DIR_PATH/$COVER_NAME.$first_image_ext"
    if cp -f "$first_image_path" "$COVER_PATH"; then
        echo "   ✅ 建立封面成功。" >&2
    else
        echo "   ❌ 建立封面失敗。" >&2
        prep_ok=false
    fi

    # 3. 移動所有圖片到章節資料夾
    local moved_count=0
    
    # <--- FIX: 修正 Subshell 和無限迴圈問題 --->
    local temp_file=$(mktemp)
    # 將 find 輸出寫入臨時檔案
    find "$DIR_PATH" -maxdepth 1 -type f -name "${NEW_NAME_PREFIX}*.*" -print0 > "$temp_file"
    
    # **關鍵修正：將 < "$temp_file" 放在 done 之後**
    # 這樣 while 迴圈會在當前 Shell 執行，並正確讀取整個檔案直到結束
    while IFS= read -r -d $'\0' IMAGE_FILE; do 
        
        if mv -f "$IMAGE_FILE" "$CHAPTER_DIR/"; then
            moved_count=$((moved_count + 1))
        else
            echo "   ❌ 錯誤：移動 $IMAGE_FILE 到 $CHAPTER_DIR 失敗。" >&2
            prep_ok=false
        fi
    done < "$temp_file" # <--- CORRECTED POSITION

    rm -f "$temp_file" # 清理臨時檔案
    # <--- END FIX --->

    # 修正計數邏輯：報告預期總數與實際移動數
    if $prep_ok && [ "$moved_count" -eq "$TOTAL_IMAGE_COUNT" ]; then
        echo "   ✅ 已建立 $CHAPTER_FOLDER，移動 $moved_count / $TOTAL_IMAGE_COUNT 張圖片。" >&2
        return 0 # 成功
    else
        # 如果移動數量不符，或者有檔案移動失敗
        prep_ok=false
        echo "   ❌ 失敗: 移動階段出錯 ($moved_count / $TOTAL_IMAGE_COUNT 移動成功)。" >&2
        return 1 # 失敗
    fi
}

# --- 主要執行邏輯 (批次處理) ---

# 尋找所有一級子資料夾
find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' DIR_PATH; do
    
    # 1. 核心過濾檢查 (必須有 m4)
    if [ ! -f "${DIR_PATH}/m4" ]; then
        continue 
    fi
    
    # 2. 安全檢查 (終端信標跳過)
    if [ -f "${DIR_PATH}/mi" ] || [ -f "${DIR_PATH}/md" ]; then
        echo "   ✅ 已完成或封裝 ➡️ 跳過。" >&2
        continue 
    fi

    echo "▶️  正在處理 $DIR_PATH" >&2
    
    # 執行處理函式
    if process_series_folder "$DIR_PATH"; then
        # 成功後：1. 移除 m4 2. 新增 mi
        if [ -f "${DIR_PATH}/m4" ]; then
            rm "${DIR_PATH}/m4"
            touch "${DIR_PATH}/mi" # <<<--- 新增 mi 標記
            echo "---" >&2 
        fi
    else
        # 處理失敗時，保留 m4，等待下次處理或手動檢查
        echo "   ❌ 處理失敗，等待下次處理或手動檢查" >&2
        rm "${DIR_PATH}/m4"
        touch "${DIR_PATH}/mf" # <<<--- 新增 mf 標記
        echo "---" >&2 
    fi
    
done

echo "漫畫結構目錄主體建立作業已完成。" >&2

exit 0