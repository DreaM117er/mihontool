#!/bin/bash

MAIN_DIR="$(pwd)" 
ERROR_LOG="$MAIN_DIR/markdown-error-$(date +%Y%m%d%H%M%S).log"
# **信標列表**
MARKERS=("mi" "md" "m0" "m1" "m2" "m3" "m4" "mf")

echo "---" >&2
echo "執行掃描標記漫畫資料夾..."
echo "掃描目標: $MAIN_DIR"

# 確保 error log 是空的或創建它
> "$ERROR_LOG"

# --- 步驟 1: 移除主目錄中的空資料夾 ---
echo "---"
echo "▶️  正在移除 '$MAIN_DIR' 中的空資料夾..."
find "$MAIN_DIR" -maxdepth 1 -type d -empty -not -path "$MAIN_DIR" -exec rm -rf {} \;
echo "   ✅ 空資料夾清理完成。"
echo "---"

# --- 核心處理函式：處理單個目標資料夾 ---
process_folder() {
    local TARGET_DIR="$1"
    
    if [ "$TARGET_DIR" == "." ]; then return; fi
    if [[ "$TARGET_DIR" == ._* || "$TARGET_DIR" == .git* ]]; then return; fi

    echo "▶️  正在掃描: $TARGET_DIR"
    
    cd "$TARGET_DIR" || { echo "❌ 錯誤：無法進入 $TARGET_DIR。" >> "$ERROR_LOG"; return; }

    # --- 步驟 2: 掃描並移除所有已存在的信標 ---
    for marker in "${MARKERS[@]}"; do
        [ -f "$marker" ] && rm "$marker"
    done

    # --- 條件判斷主邏輯 ---
    IMAGE_COUNT=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" \) | wc -l)
    SUBDIR_COUNT=$(find . -maxdepth 1 -type d -not -name "." | wc -l)
    
    MARKER_FOUND=0

    # ----------------------------------------------------
    # A. 圖片數量 = 1 的情況 (已結構化檢查 - 衝突優先)
    # ----------------------------------------------------
    if [ "$IMAGE_COUNT" -eq 1 ]; then
        
        HAS_COVER_FILE=$(find . -maxdepth 1 -type f -iname "cover.*" | wc -l)
        
        # 結構元素計數 (CBZ 或非空資料夾)
        HAS_CBZ=0
        if [ -s "chapter_1.cbz" ]; then HAS_CBZ=1; fi
        HAS_NON_EMPTY_DIR=0
        if [ -d "chapter_1" ] && [ "$(find "chapter_1" -type f | wc -l)" -gt 0 ]; then HAS_NON_EMPTY_DIR=1; fi
        
        STRUCTURE_COUNT=$((HAS_CBZ + HAS_NON_EMPTY_DIR))
        
        
        # -------------------------------------
        # A.0 衝突檢查 (STRUCTURE_COUNT = 2)
        # -------------------------------------
        if [ "$STRUCTURE_COUNT" -eq 2 ]; then
            echo "   ❌ 結構混亂：同時存在 chapter_1 資料夾和 chapter_1.cbz。將標記 mf。"
        
        # -------------------------------------
        # A.1 & A.2 & A.3 正常判斷
        # -------------------------------------
        # 有封面 (mi/md 判斷)
        elif [ "$HAS_COVER_FILE" -gt 0 ]; then
            
            # A.2. (md): 只有 CBZ 存在 (STRUCTURE_COUNT=1 且 HAS_CBZ=1)
            if [ "$HAS_CBZ" -eq 1 ]; then
                touch md 
                echo "   ✅ 標記 md: 有 cover.ext 且 chapter_1.cbz 存在。"
                MARKER_FOUND=1
            
            # A.1. (mi): 只有非空 chapter_1 資料夾存在 (STRUCTURE_COUNT=1 且 HAS_NON_EMPTY_DIR=1)
            elif [ "$HAS_NON_EMPTY_DIR" -eq 1 ]; then
                touch mi 
                echo "   ✅ 標記 mi: 有 cover.ext 且 chapter_1 資料夾不為空。"
                MARKER_FOUND=1
            
            # 其他情況 (STRUCTURE_COUNT=0): 只有封面，沒有結構，掉入 C 區塊標記 mf
            fi
        
        # 無封面 (m3 判斷)
        elif [ "$HAS_COVER_FILE" -eq 0 ]; then

            # A.3. (m3): 只有一個結構元素存在 (STRUCTURE_COUNT=1)
            if [ "$STRUCTURE_COUNT" -eq 1 ]; then
                touch m3
                echo "   ✅ 標記 m3: 結構存在 (單一 CBZ 或 資料夾)，但封面遺失。"
                MARKER_FOUND=1
            
            # 其他情況 (STRUCTURE_COUNT=0): 無結構，掉入 C 區塊標記 mf
            fi
        fi
        
    # ----------------------------------------------------
    # B. 圖片數量 > 1 且沒有結構化子資料夾 (核心處理區)
    # ----------------------------------------------------
    elif [ "$IMAGE_COUNT" -gt 1 ] && [ "$SUBDIR_COUNT" -eq 0 ]; then
        
        HAS_IMAGE_PREFIX=$(find . -maxdepth 1 -type f -regex ".*image_[0-9][0-9][0-9]\..*" | wc -l)
        ALL_NON_WEBP=$(find . -maxdepth 1 -type f -not -iname "*.webp" | grep -E '\.(jpg|jpeg|png|gif|bmp)$' | wc -l)

        # 優先級 1 (m4): 有前綴且全為 WEBP (待排序)
        if [ "$HAS_IMAGE_PREFIX" -gt 0 ] && [ "$ALL_NON_WEBP" -eq 0 ]; then
            touch m4
            echo "   ✅ 標記 m4: 圖片有 image_XXX 前綴命名，且全部為 .webp (待排序/去前綴)。"
            MARKER_FOUND=1
            
        # 優先級 2 (m2): 有前綴且有非 WEBP (待轉換)
        elif [ "$HAS_IMAGE_PREFIX" -gt 0 ] && [ "$ALL_NON_WEBP" -gt 0 ]; then
            touch m2
            echo "   ✅ 標記 m2: 圖片有 image_XXX 前綴命名，但含有非 .webp 圖片 (待轉換)。"
            MARKER_FOUND=1

        # 優先級 3 (m0): 無前綴且全為 WEBP (待結構化)
        elif [ "$ALL_NON_WEBP" -eq 0 ] && [ "$HAS_IMAGE_PREFIX" -eq 0 ]; then
            touch m0
            echo "   ✅ 標記 m0: 所有圖片皆為 .webp 且無 image_XXX 前綴 (準備結構化)。"
            MARKER_FOUND=1
        
        # 優先級 4 (m1): 無前綴且有非 WEBP (待轉換)
        elif [ "$ALL_NON_WEBP" -gt 0 ] && [ "$HAS_IMAGE_PREFIX" -eq 0 ]; then
            touch m1
            echo "   ✅ 標記 m1: 有非 .webp 圖片，且無 image_XXX 前綴 (準備轉換)。"
            MARKER_FOUND=1
        fi

    fi

    # ----------------------------------------------------
    # C. 上述條件都未達成 (mf)
    # ----------------------------------------------------
    if [ "$MARKER_FOUND" -eq 0 ]; then
        touch mf
        ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') - 資料夾: $TARGET_DIR - 未匹配任何條件。"
        echo "$ERROR_MESSAGE" >> "$MAIN_DIR/$ERROR_LOG"
        echo "   ❌ 標記 mf: 未匹配任何條件，寫入 error log。"
    fi
    
    cd "$MAIN_DIR"
    echo "---"
}

# --- 步驟 3: 遍歷主目錄下的所有子資料夾並執行處理函式 ---
find . -maxdepth 1 -type d -not -name "." | while read -r folder; do
    folder_name="${folder#./}" 
    process_folder "$folder_name"
done

echo "掃描及標記資料夾已完成。"
echo "請檢查 $ERROR_LOG 以查看錯誤詳情。"