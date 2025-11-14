#!/bin/bash

# --- 配置參數 ---
MARKERS=("m0" "m1" "m2" "m3" "m4" "mi" "md" "mf")
MAIN_DIR="$(pwd)"
STATS_FILE="folderstate.txt" # 輸出檔名簡化，方便排除

# 診斷步驟 1: 輸出目前工作目錄

# 初始化統計計數器
declare -A counts
for marker in "${MARKERS[@]}"; do
    counts[$marker]=0
done
counts["TOTAL_DIRS"]=0
counts["NO_MARKER"]=0

# ----------------------------------------------------
# 1. 掃描所有一級子資料夾 (Globbing 方式)
# ----------------------------------------------------
echo "正在計算已被標記的資料夾..."
echo "執行目標 $(pwd) ..."

# 核心修正：使用 Globbing 方式 '*/' 來列出所有非隱藏的一級資料夾
for DIR_PATH_FULL in */ ; do
    
    # 移除 Globbing 產生的結尾斜線 (例如: 'Manga01/' -> 'Manga01')
    DIR_PATH="${DIR_PATH_FULL%/}"

    # 🚨 關鍵修正：排除 STATS_FILE 自身 (如果它被錯誤識別為資料夾)
    if [ "$DIR_PATH" == "$STATS_FILE" ]; then
        continue
    fi

    # 排除隱藏資料夾 (Globbing 本身已排除 .*)
    if [ "$DIR_PATH" == "." ] || [ "$DIR_PATH" == ".." ]; then
        continue
    fi
    
    # 確保是資料夾
    if [ ! -d "$DIR_PATH" ]; then
        continue
    fi

    counts["TOTAL_DIRS"]=$((counts["TOTAL_DIRS"] + 1))
    
    FOUND_MARKER=false
    
    # 檢查每個信標
    for marker in "${MARKERS[@]}"; do
        # 檔案檢查：直接檢查相對路徑
        if [ -f "$DIR_PATH/$marker" ]; then
            counts[$marker]=$((counts[$marker] + 1))
            FOUND_MARKER=true
            break 
        fi
    done
    
    # 如果資料夾存在，但沒有任何信標
    if ! $FOUND_MARKER; then
        counts["NO_MARKER"]=$((counts["NO_MARKER"] + 1))
    fi

done

# ----------------------------------------------------
# 2. 輸出結果
# ----------------------------------------------------
# 確保時間戳記是最新的
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 由於您希望變更輸出檔名，這裡再次組合完整路徑
FULL_STATS_FILE="$MAIN_DIR/$STATS_FILE"

# 寫入結果
echo "---" > "$FULL_STATS_FILE"
echo "📜 總計: ${counts[TOTAL_DIRS]} 個 資料夾" >> "$FULL_STATS_FILE"
echo "📜 總計: ${counts[NO_MARKER]} 個 未被標記" >> "$FULL_STATS_FILE"
echo "---" >> "$FULL_STATS_FILE"
# 輸出核心處理信標 (M-系列)
echo "✅ chapter_1: ${counts[mi]} 個 已完成 (folder)" >> "$FULL_STATS_FILE"
echo "✅ chapter_1: ${counts[md]} 個 已封裝 (.cbz)" >> "$FULL_STATS_FILE"
echo "---" >> "$FULL_STATS_FILE"
echo "⚠️  資料夾 ${counts[m3]} 個 無封面" >> "$FULL_STATS_FILE"
echo "❌ 資料夾 ${counts[mf]} 個 結構/檔案錯誤" >> "$FULL_STATS_FILE"
echo "---" >> "$FULL_STATS_FILE"
echo "📝 資料夾 ${counts[m1]} 個 未經過處理" >> "$FULL_STATS_FILE"
echo "📝 資料夾 ${counts[m4]} 個 需調整架構" >> "$FULL_STATS_FILE"
echo "📝 資料夾 ${counts[m2]} 個 已經過 image_ 命名/需轉檔 (webp)" >> "$FULL_STATS_FILE"
echo "📝 資料夾 ${counts[m0]} 個 已轉檔 (webp)/需 image_ 命名" >> "$FULL_STATS_FILE"
echo "---" >> "$FULL_STATS_FILE"
echo "▶️  掃描標記時間: ($TIMESTAMP)" >> "$FULL_STATS_FILE"

echo "掃描結束。"
cat "$FULL_STATS_FILE"