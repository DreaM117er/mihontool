#!/bin/bash
# frename.sh (V2 - 嚴格驗證器 "CoverCheck")
# 職責：檢查 mi, md, m3 標記的資料夾，驗證章節完整性與 cover.webp

# --- 配置參數 ---
ERROR_LOG="errorlog.txt"
COVER_FILE="cover.webp" # 堅持單一格式，我們只檢查 cover.webp

echo "---" >&2
echo "執行嚴格驗證 (章節完整性 / 封面檢查)..." >&2
echo "---" >&2

# --- 輔助函式：章節驗證器 ---
# 傳入 $1: 資料夾路徑 (例如 ./[Manga])
# 返回 0: 驗證通過 (章節完整, 結構良好)
# 返回 1: 驗證失敗 (斷章, 重複, 或非數字)
# 返回 2: 驗證通過，但是 "混合模式" (m3 -> mi)
validate_chapters() {
    local base_dir="$1"
    
    # 1. 抓取所有 chapter_n 的 "數字"
    # (同時抓取 .cbz 和 資料夾，並移除後綴)
    local all_numbers
    all_numbers=$(find "$base_dir" -maxdepth 1 \
        \( -type d -iname "chapter_*" \) -o \
        \( -type f -iname "chapter_*.cbz" \) | \
        while IFS= read -r f; do
            local base
            base=$(basename "$f")
            [[ "$base" == *".cbz" ]] && base="${base%.cbz}"
            echo "$base"
        done | \
        sed 's/^chapter_//' | \
        grep '^[0-9]\+$' | \
        sort -n) # 數值排序

    if [ -z "$all_numbers" ]; then
        # 找不到任何 chapter_N，但有 mi/md/m3 標記，這本身就是個錯誤
        return 1 # 失敗
    fi

    # 2. 檢查重複 (uniq -d 會找出重複的行)
    if [ -n "$(echo "$all_numbers" | uniq -d)" ]; then
        echo "   ❌ 檢查完畢: 偵測到重複的章節編號。" >&2
        return 1 # 失敗
    fi

    # 3. 檢查連續性 (使用 awk)
    local gap_result
    gap_result=$(echo "$all_numbers" | awk '
        BEGIN { prev=0 }
        {
            if (NR == 1 && $1 != 1) { print "gap_start"; exit }
            if (NR > 1 && $1 != prev + 1) { print "gap_middle"; exit }
            prev=$1
        }
    ')

    if [ -n "$gap_result" ]; then
        echo "   ❌ 檢查完畢: 章節不連續 (非從第 1 章開始，或中間有斷章)。" >&2
        return 1 # 失敗
    fi

    # 4. 檢查是 "單一結構" 還是 "混合結構"
    local has_dir
    local has_cbz
    has_dir=$(find "$base_dir" -maxdepth 1 -type d -iname "chapter_*" | wc -l)
    has_cbz=$(find "$base_dir" -maxdepth 1 -type f -iname "chapter_*.cbz" | wc -l)

    if [ "$has_dir" -gt 0 ] && [ "$has_cbz" -gt 0 ]; then
        # 邏輯 3: 混合但完整 -> 返回 2
        return 2 # 混合模式 (m3)
    else
        # 邏輯 1 & 2: 單一結構且完整 -> 返回 0
        return 0 # 驗證通過
    fi
}

# --- 核心邏輯：遍歷所有資料夾 ---

find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' DIR_PATH; do
    
    # 1. 核心過濾：只檢查 mi, md, m3
    CURRENT_MARKER=""
    if [ -f "$DIR_PATH/mi" ]; then
        CURRENT_MARKER="mi"
    elif [ -f "$DIR_PATH/md" ]; then
        CURRENT_MARKER="md"
    elif [ -f "$DIR_PATH/m3" ]; then
        CURRENT_MARKER="m3"
    else
        continue # 沒有目標標記，跳過
    fi
    
    # (安全檢查：跳過 mf)
    if [ -f "$DIR_PATH/mf" ]; then
        continue
    fi

    echo "▶️  正在檢查: $DIR_PATH" >&2
    
    VALIDATION_FAILED=false

    # --- 驗證 1: 檢查封面 ---
    if [ ! -f "$DIR_PATH/$COVER_FILE" ]; then
        echo "   ❌ 檢查完畢: 缺少封面 '$COVER_FILE'。" >&2
        VALIDATION_FAILED=true
    fi

    # --- 驗證 2: 檢查章節 ---
    # (如果封面已失敗，仍可繼續檢查章節，以提供完整錯誤報告)
    
    validate_chapters "$DIR_PATH"
    VALIDATE_RESULT=$? # 獲取輔助函式的返回碼

    if [ "$VALIDATE_RESULT" -eq 1 ]; then
        # (函式內部已印出錯誤)
        VALIDATION_FAILED=true
    fi
    
    # --- 最終裁決與狀態轉換 ---
    if $VALIDATION_FAILED; then
        echo "   ➡️  標記錯誤: 資料夾未通過結構檢查。" >&2
        rm -f "$DIR_PATH/$CURRENT_MARKER" # 移除 mi/md/m3
        touch "$DIR_PATH/mf"
        
        ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') - [Validate] 資料夾: $DIR_PATH - ❌ 資料夾結構或章節不完整。"
        echo "$ERROR_MESSAGE" >> "$ERROR_LOG"
    
    else
        # 驗證通過 (封面存在 且 章節OK)
        
        if [ "$CURRENT_MARKER" == "m3" ] && [ "$VALIDATE_RESULT" -eq 2 ]; then
            # 邏輯 3: 混合 (m3) 但完整 -> 轉換為 mi (準備打包)
            echo "   ✅ 檢查完畢: 混合結構。" >&2
            echo "   ➡️  標記可執行統合封裝。" >&2
            rm -f "$DIR_PATH/m3"
            touch "$DIR_PATH/mi"
            
        elif [ "$CURRENT_MARKER" == "m3" ]; then
            # 這是個 BUG 狀態：markdown 標記 m3 (混合)，但驗證器認為是單一結構
            echo "   ⚠️  檢查完畢: 但結構似乎是單一的，標記錯誤做手動檢查。" >&2
            rm -f "$DIR_PATH/m3"
            touch "$DIR_PATH/mf"
            ERROR_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') - [Validate] 資料夾: $DIR_PATH - ⚠️ 標記錯誤與驗證結果不符。"
            echo "$ERROR_MESSAGE" >> "$ERROR_LOG"
        
        else
            # mi 或 md 驗證通過，保持原樣
            echo "   ✅ 檢查完畢: 結構正常。" >&2
        fi
    fi
    
    echo "---" >&2

done

echo "資料夾結構檢查作業已完成。" >&2
echo "錯誤訊息（若有的話）請查看 $ERROR_LOG。" >&2

exit 0