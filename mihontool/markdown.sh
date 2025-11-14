#!/bin/bash

MAIN_DIR="$(pwd)" 
ERROR_LOG="$MAIN_DIR/markdown-error-$(date +%Y%m%d%H%M%S).log"
# **信標列表**
MARKERS=("mi" "md" "m0" "m1" "m2" "m3" "m4" "mf")

echo "---" >&2
echo "執行掃描標記漫畫資料夾..." >&2
echo "掃描目標: $MAIN_DIR" >&2
echo "錯誤日誌路徑: $(basename "$ERROR_LOG")" >&2
echo "---" >&2

# 確保 error log 是空的或創建它
> "$ERROR_LOG"

# --- 步驟 1: 移除主目錄中的空資料夾 ---
echo "▶️  正在移除 '$MAIN_DIR' 中的空資料夾..." >&2
find "$MAIN_DIR" -maxdepth 1 -type d -empty -not -path "$MAIN_DIR" -exec rm -rf {} \;
echo "   ✅ 空資料夾清理完成。" >&2
echo "---" >&2

# --- 核心處理函式：處理單個目標資料夾 ---
process_folder() {
    local TARGET_DIR="$1"

    echo "▶️  正在掃描: $TARGET_DIR" >&2
    
    # 修正語法錯誤：使用 'fi' 結束 if 語句
    if [ "$TARGET_DIR" == "." ]; then 
        return
    fi
    if [[ "$TARGET_DIR" == ._* || "$TARGET_DIR" == .git* ]]; then
        return
    fi

    # === 檢查 mf 標記並跳過 (只增不減邏輯) ===
    if [ -f "$TARGET_DIR/mf" ]; then
        echo "   ❌ 偵測到錯誤標記 ➡️  跳過。" >&2

        local ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') - [MF-SKIP] 資料夾: $TARGET_DIR - 偵測到 ❌ 標記跳過。"
        echo "$ERROR_MESSAGE" >> "$ERROR_LOG"
        echo "---" >&2

        return
    fi
    # ======================================

    # 嘗試進入目錄
    cd "$TARGET_DIR" || { 
    ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') - 資料夾: $TARGET_DIR - ❌ 嚴重錯誤：無法進入目錄。"
    echo "$ERROR_MESSAGE" >> "$ERROR_LOG"
    cd "$MAIN_DIR"
    echo "---" >&2
    return
    }
    
    # 設置當前目錄名稱的變數，確保在日誌中記錄正確
    CURRENT_FOLDER_NAME=$(basename "$TARGET_DIR")

    # --- 步驟 2: 掃描並移除所有已存在的信標 ---
    for marker in "${MARKERS[@]}"; do
        [ -f "$marker" ] && rm "$marker"
    done

    # --- 條件判斷主邏輯 (保持不變) ---
    IMAGE_COUNT=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" \) | wc -l)
    SUBDIR_COUNT=$(find . -maxdepth 1 -type d -not -name "." | wc -l)
    
    MARKER_FOUND=0
    
    # [ A, B 區塊邏輯保持不變 ]
    
    if [ "$IMAGE_COUNT" -eq 1 ]; then
        HAS_COVER_FILE=$(find . -maxdepth 1 -type f -iname "cover.*" | wc -l)
        HAS_CBZ=0
        if [ -s "chapter_1.cbz" ]; then HAS_CBZ=1; fi
        HAS_NON_EMPTY_DIR=0
        if [ -d "chapter_1" ] && [ "$(find "chapter_1" -type f | wc -l)" -gt 0 ]; then HAS_NON_EMPTY_DIR=1; fi
        STRUCTURE_COUNT=$((HAS_CBZ + HAS_NON_EMPTY_DIR))
        
        if [ "$STRUCTURE_COUNT" -eq 2 ]; then
            echo "   ❌ 結構混亂：同時存在 chapter_1 資料夾和 chapter_1.cbz。" >&2
            touch mf
            ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') -  ❌ 資料夾: $CURRENT_FOLDER_NAME - 結構混亂。"
            echo "$ERROR_MESSAGE" >> "$ERROR_LOG"
        elif [ "$HAS_COVER_FILE" -gt 0 ]; then
            if [ "$HAS_CBZ" -eq 1 ] && [ "$HAS_NON_EMPTY_DIR" -eq 0 ]; then
                touch md 
                echo "   ✅ 標記成功: 有 cover.ext 且 chapter_1.cbz 存在。" >&2
                MARKER_FOUND=1
            elif [ "$HAS_NON_EMPTY_DIR" -eq 1 ] && [ "$HAS_CBZ" -eq 0 ]; then
                touch mi 
                echo "   ✅ 標記成功: 有 cover.ext 且 chapter_1 資料夾不為空。" >&2
                MARKER_FOUND=1
            fi
        elif [ "$HAS_COVER_FILE" -eq 0 ]; then
            if [ "$STRUCTURE_COUNT" -eq 1 ]; then
                touch m3
                echo "   ⚠️  標記成功: 結構存在 (單一 CBZ 或 資料夾)，但封面遺失。" >&2
                MARKER_FOUND=1
            fi
        fi
    elif [ "$IMAGE_COUNT" -gt 1 ] && [ "$SUBDIR_COUNT" -eq 0 ]; then
        HAS_IMAGE_PREFIX=$(find . -maxdepth 1 -type f -regex ".*image_[0-9][0-9][0-9]\..*" | wc -l)
        ALL_NON_WEBP=$(find . -maxdepth 1 -type f -not -iname "*.webp" | grep -E '\.(jpg|jpeg|png|gif|bmp)$' | wc -l)

        if [ "$HAS_IMAGE_PREFIX" -gt 0 ] && [ "$ALL_NON_WEBP" -eq 0 ]; then
            touch m4
            echo "   📝 標記成功: 資料夾內需調整 chapter_1 架構。" >&2
            MARKER_FOUND=1
        elif [ "$HAS_IMAGE_PREFIX" -gt 0 ] && [ "$ALL_NON_WEBP" -gt 0 ]; then
            touch m2
            echo "   📝 標記成功: 圖片經過 image_XXX 標準化命名，未經過 .webp 格式轉換。" >&2
            MARKER_FOUND=1
        elif [ "$ALL_NON_WEBP" -eq 0 ] && [ "$HAS_IMAGE_PREFIX" -eq 0 ]; then
            touch m0
            echo "   📝 標記成功: 所有圖片經過 .webp 格式轉換，未經過 image_XXX 標準化命名。" >&2
            MARKER_FOUND=1
        elif [ "$ALL_NON_WEBP" -gt 0 ] && [ "$HAS_IMAGE_PREFIX" -eq 0 ]; then
            touch m1
            echo "   📝 標記成功: 資料夾未經過處理。" >&2
            MARKER_FOUND=1
        fi
    fi
    
    # ----------------------------------------------------
    # C. 上述條件都未達成 (標記 mf 並寫入日誌)
    # ----------------------------------------------------
    if [ "$MARKER_FOUND" -eq 0 ]; then
        touch mf
        ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') -  ❌ 資料夾: $CURRENT_FOLDER_NAME - 搜尋到標記錯誤。"
        echo "$ERROR_MESSAGE" >> "$ERROR_LOG"
        echo "   ❌ 搜尋到錯誤標記，記錄到 markdown-error-$(date '+%Y%m%d%H%M%S').log。" >&2
    fi
    
    cd "$MAIN_DIR"
    echo "---" >&2
}

# --- 步驟 3: 遍歷主目錄下的所有子資料夾並執行處理函式 ---
find . -maxdepth 1 -type d -not -name "." | while read -r folder; do
    folder_name="${folder#./}" 
    process_folder "$folder_name"
done

echo "掃描及標記資料夾已完成。" >&2
echo "請檢查 $ERROR_LOG 以查看錯誤詳情。" >&2

exit 0