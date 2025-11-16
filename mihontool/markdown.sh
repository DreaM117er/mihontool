#!/bin/bash

MAIN_DIR="$(pwd)" 
ERROR_LOG="$MAIN_DIR/errorlog.txt"
# **信標列表**
MARKERS=("mi" "md" "m0" "m1" "m2" "m3" "m4" "mf")

echo "---" >&2
echo "執行掃描標記漫畫資料夾..." >&2
echo "掃描目標: $MAIN_DIR" >&2
echo "錯誤日誌路徑: $(basename "$ERROR_LOG")" >&2
echo "---" >&2
echo "▶️  正在移除 '$MAIN_DIR' 中的空資料夾..." >&2
find "$MAIN_DIR" -maxdepth 1 -type d -empty -not -path "$MAIN_DIR" -exec rm -rf {} \;
echo "   ✅ 空資料夾清理完成。" >&2
echo "---" >&2

# --- 核心處理函式：處理單個目標資料夾 ---
process_folder() {
    local TARGET_DIR="$1"

    echo "▶️  正在掃描: $TARGET_DIR" >&2
    
    if [ "$TARGET_DIR" == "." ]; then 
        return
    fi
    if [[ "$TARGET_DIR" == ._* || "$TARGET_DIR" == .git* ]]; then
        return
    fi

    # === 檢查 mf 標記並跳過 (只增不減邏輯) ===
    if [ -f "$TARGET_DIR/mf" ]; then
        echo "   ❌ 偵測到錯誤標記。" >&2
        echo "   ➡️  將標記錯誤記錄到 errorlog.txt 內。" >&2
        local ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') - ❌ 資料夾: $TARGET_DIR - 偵測到錯誤跳過。"
        echo "$ERROR_MESSAGE" >> "$ERROR_LOG"
        echo "---" >&2

        return
    fi
    # ======================================

    # 嘗試進入目錄
    cd "$TARGET_DIR" || { 
    ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') - 資料夾: $TARGET_DIR - ❌ 嚴重錯誤：無法進入目錄。"
    echo "   ➡️  將標記錯誤記錄到 errorlog.txt 內。" >&2
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

    # --- (!! V6: 移除了 check_chapter_continuity 函式 !!) ---

    # --- 條件判斷主邏輯 (V6 - 恢復空資料夾檢查，移除連續性檢查) ---
    
    # 1. 取得計數
    IMAGE_COUNT=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \) | wc -l)
    HAS_CHAPTER_CBZ_COUNT=$(find . -maxdepth 1 -type f -iname "chapter_*.cbz" | wc -l)
    HAS_CHAPTER_DIR_COUNT=$(find . -maxdepth 1 -type d -iname "chapter_*" | wc -l)
    
    MARKER_FOUND=0

    # ---
    # 邏輯 1: (m3) 結構混亂 (任何 CBZ 和 Dir 混合存在)
    # ---
    if [ "$HAS_CHAPTER_CBZ_COUNT" -gt 0 ] && [ "$HAS_CHAPTER_DIR_COUNT" -gt 0 ]; then
        touch m3 
        echo "   ⚠️  標記成功: 結構混亂，同時存在 chapter_n.cbz 和 chapter_n 資料夾，需做進一步檢查。" >&2
        MARKER_FOUND=1
    
    # ---
    # 邏輯 2: (md) 僅存在 CBZ 結構 (不檢查連續性)
    # ---
    elif [ "$HAS_CHAPTER_CBZ_COUNT" -gt 0 ] && [ "$HAS_CHAPTER_DIR_COUNT" -eq 0 ]; then
        touch md 
        echo "   ✅ 標記成功: 偵測到 chapter_n.cbz 結構，合計 $HAS_CHAPTER_CBZ_COUNT 個。" >&2
        MARKER_FOUND=1

    # ---
    # 邏輯 3: (mi) 僅存在 Dir 結構 (!!恢復空資料夾檢查!!)
    # ---
    elif [ "$HAS_CHAPTER_DIR_COUNT" -gt 0 ] && [ "$HAS_CHAPTER_CBZ_COUNT" -eq 0 ]; then

        # (!!恢復!!) 檢查 (Condition 4): 確保至少一個 chapter_n 資料夾不是空的
        local ALL_CHAPTER_DIRS_EMPTY=1 # 假設全空
        while IFS= read -r -d $'\0' chap_dir; do
            # find ... -print -quit: 找到第一個檔案就停止並印出，-n 檢查是否有印出
            if [ -n "$(find "$chap_dir" -type f -print -quit)" ]; then
                ALL_CHAPTER_DIRS_EMPTY=0 # 找到檔案，標記為 "非全空"
                break
            fi
        done < <(find . -maxdepth 1 -type d -iname "chapter_*" -print0)
        
        if [ "$ALL_CHAPTER_DIRS_EMPTY" -eq 1 ]; then
            echo "   ❌ 標記成功: 偵測到 chapter 資料夾，但所有資料夾都沒有圖片，標記錯誤。" >&2
            # MARKER_FOUND 保持為 0...
        else
            # (已移除連續性檢查)
            touch mi 
            echo "   ✅ 標記成功: 偵測到 chapter 資料夾，合計 $HAS_CHAPTER_DIR_COUNT 個。" >&2
            MARKER_FOUND=1
        fi

    # ---
    # 邏輯 4: (原 m0/m1/m2/m4 邏輯) 平鋪資料夾
    # ---
    elif [ "$HAS_CHAPTER_CBZ_COUNT" -eq 0 ] && [ "$HAS_CHAPTER_DIR_COUNT" -eq 0 ]; then
        
        # 取得總子目錄數 (如果_COUNT=0, 表示為平鋪)
        local SUBDIR_COUNT=$(find . -maxdepth 1 -type d -not -name "." | wc -l)
        
        if [ "$IMAGE_COUNT" -gt 1 ] && [ "$SUBDIR_COUNT" -eq 0 ]; then
            HAS_IMAGE_PREFIX=$(find . -maxdepth 1 -type f -regex ".*image_[0-9][0-9][0-9]\..*" | wc -l)
            ALL_NON_WEBP=$(find . -maxdepth 1 -type f -not -iname "*.webp" | grep -E '\.(jpg|jpeg|png|gif|bmp)$' | wc -l)

            if [ "$HAS_IMAGE_PREFIX" -gt 0 ] && [ "$ALL_NON_WEBP" -eq 0 ]; then
                touch m4
                echo "   📝 標記成功: 資料夾需調整架構。" >&2
                MARKER_FOUND=1
            elif [ "$HAS_IMAGE_PREFIX" -gt 0 ] && [ "$ALL_NON_WEBP" -gt 0 ]; then
                touch m2
                echo "   📝 標記成功: 圖片都已做 image_ 標準化命名, 但未轉換 webp 格式。" >&2
                MARKER_FOUND=1
            elif [ "$ALL_NON_WEBP" -eq 0 ] && [ "$HAS_IMAGE_PREFIX" -eq 0 ]; then
                touch m0
                echo "   📝 標記成功: 圖片都已轉換 webp 格式，但需要做 image_ 標準化命名, 。" >&2
                MARKER_FOUND=1
            elif [ "$ALL_NON_WEBP" -gt 0 ] && [ "$HAS_IMAGE_PREFIX" -eq 0 ]; then
                touch m1
                echo "   📝 標記成功: 資料夾未經過處理。" >&2
                MARKER_FOUND=1
            fi
        fi
    fi
    
    # ----------------------------------------------------
    # C. 上述條件都未達成 (標記 mf 並寫入日誌)
    # ----------------------------------------------------
    if [ "$MARKER_FOUND" -eq 0 ]; then
        touch mf
        ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') - ❌ 資料夾: $CURRENT_FOLDER_NAME - 標記錯誤。"
        echo "$ERROR_MESSAGE" >> "$ERROR_LOG"
        echo "   ➡️  將標記錯誤記錄到 errorlog.txt 內。" >&2
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
echo "請檢查 errorlog.txt 以查看錯誤詳情。" >&2

exit 0