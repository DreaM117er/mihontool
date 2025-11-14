#!/bin/bash
# frename.sh (專門處理 m3 標記資料夾：將 [anyname].ext 更名為 cover.ext)

# --- 配置參數 ---
PARENT_DIR="."
# 允許的圖片副檔名 (用於識別根目錄下的單圖)
TARGET_EXTENSIONS="jpg jpeg png bmp webp gif JPG JPEG PNG BMP WEBP GIF" 
CHAPTER_FOLDER="chapter_1" # 新增：用於判斷 mi/md 狀態的資料夾名稱

echo "---" >&2
echo "開始檢查是否有封面不存在的資料夾..." >&2

LOG_TEMP="temp_m3_success_log_$$"
IMAGE_FILES_TEMP=$(mktemp) # 用於暫存符合條件的單一圖片路徑

> "$LOG_TEMP"

# 1. 尋找所有一級子資料夾
find "${PARENT_DIR}" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r DIR
do
    # 2. 核心過濾檢查 (必須有 m3，且沒有 mi/md)
    if [ ! -f "${DIR}/m3" ]; then
        continue 
    fi
    
    if [ -f "${DIR}/mi" ] || [ -f "${DIR}/md" ]; then
        echo "➡️ 跳過: $DIR (已包含 mi/md 終端信標)" >&2
        continue 
    fi

    echo "---" >&2
    echo "▶️  正在檢查 $DIR" >&2
    
    # 3. 找出根目錄下的唯一圖片檔案
    
    # 清空臨時檔案以備用
    > "$IMAGE_FILES_TEMP" 
    
    # 構建 find 篩選條件
    FIND_FILTER=""
    first=true
    for ext in $TARGET_EXTENSIONS; do
        if [ "$first" = true ]; then
            FIND_FILTER="-iname *.$ext"
            first=false
        else
            FIND_FILTER="$FIND_FILTER -o -iname *.$ext"
        fi
    done
    
    # 執行 find，將非 cover.* 的圖片路徑寫入臨時檔案
    find "$DIR" -maxdepth 1 -type f \( $FIND_FILTER \) -print0 | while IFS= read -r -d $'\0' FILE_PATH
    do
        # 排除已是 cover.ext 的檔案，以確保我們要更名的是「非 cover」的單圖
        if [[ "$(basename "$FILE_PATH" | tr '[:upper:]' '[:lower:]')" != cover.* ]]; then
            echo "$FILE_PATH" >> "$IMAGE_FILES_TEMP"
        fi
    done

    # 4. 判斷並執行更名 (使用 wc 取得準確的檔案計數)
    IMAGE_COUNT=$(wc -l < "$IMAGE_FILES_TEMP")

    if [ "$IMAGE_COUNT" -eq 1 ]; then
        
        # 從臨時檔案中讀取唯一的檔案路徑
        TARGET_IMAGE=$(cat "$IMAGE_FILES_TEMP")
        
        # 提取副檔名
        ORIGINAL_EXT="${TARGET_IMAGE##*.}"
        TARGET_PATH="${DIR}/cover.${ORIGINAL_EXT}"
        
        # 執行重新命名
        if mv -f "${TARGET_IMAGE}" "${TARGET_PATH}"; then
            echo "   ✅ 已修復封面: $(basename "$TARGET_IMAGE") -> cover.${ORIGINAL_EXT}" >&2
            
            # --- 核心信標判斷邏輯 (新增) ---
            
            # 1. 移除 m3
            rm -f "${DIR}/m3"
            
            # 2. 決定新增 mi 還是 md (根據您的要求)
            if [ -f "${DIR}/${CHAPTER_FOLDER}.cbz" ]; then
                # 存在 cbz 檔案，新增 md (已打包)
                touch "${DIR}/md"
                echo "   ✅ 主體封裝已完成。" >&2
            elif [ -d "${DIR}/${CHAPTER_FOLDER}" ]; then
                # 存在 chapter_1 資料夾，新增 mi (結構建制完成)
                touch "${DIR}/mi" 
                echo "   ✅ 結構主體已完成。" >&2 
            else
                # 預設：單圖更名完成，視為最終結構 mi (因為單圖不需要 chapter_1 資料夾)
                touch "${DIR}/mi" 
                echo "   ✅ 結構主體已完成。" >&2 
            fi
            
            # ------------------------------------

        else
            echo "   ❌ 錯誤：無法重新命名 ${TARGET_IMAGE}。" >&2
        fi
        
    elif [ "$IMAGE_COUNT" -gt 1 ]; then
        echo "   ❌ 錯誤：發現 $IMAGE_COUNT 個圖片檔案，主體結構有問題 ➡️ 跳過。" >&2
    else
        echo "   ❌ 警告：未找到非 cover.ext 命名的單一圖片檔案 / 存在其他不相干的檔案 ➡️ 跳過。" >&2
    fi

done

# 清理臨時檔案
rm -f "$IMAGE_FILES_TEMP" 2>/dev/null
rm -f "$LOG_TEMP" 2>/dev/null

echo "---" >&2
echo "資料夾檢查完畢。" >&2

exit 0