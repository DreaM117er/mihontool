#!/bin/bash

# --- 配置參數 ---
SOURCE_EXTS="jpg,jpeg,png,bmp,JPG,JPEG,PNG,BMP"
TARGET_EXT="webp"
QUALITY=80
ERROR_LOG="errorlog.txt"

echo "---" >&2
echo "執行 webp 轉換..." >&2 # 導向 STDERR
echo "---" >&2

# 構建 find 篩選條件字串
FIND_FILTER_STRING=""
IFS=',' read -r -a extensions <<< "$SOURCE_EXTS"
first_ext="true" 
for ext in "${extensions[@]}"; do
    if [ "$first_ext" = "false" ]; then 
        FIND_FILTER_STRING="$FIND_FILTER_STRING -o "
    fi
    FIND_FILTER_STRING="$FIND_FILTER_STRING -iname *.$ext"
    first_ext="false"
done

# -------------------------------------------------- >&2

# --- 核心邏輯：Directory Loop ---

# 尋找所有一級子資料夾
find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' DIR_PATH; do

    # 1. 檢查信標
    MARKER_PRESENT=""
    NEXT_MARKER=""
    
    if [ -f "$DIR_PATH/m1" ]; then
        MARKER_PRESENT="m1"
        NEXT_MARKER="m0" # m1 (無前綴, 非WEBP) -> 轉換 -> m0 (無前綴, WEBP)
    elif [ -f "$DIR_PATH/m2" ]; then
        MARKER_PRESENT="m2"
        NEXT_MARKER="m4" # m2 (有前綴, 非WEBP) -> 轉換 -> m4 (有前綴, WEBP)
    else
        continue
    fi
    
    # 安全檢查 (終端信標跳過)
    if [ -f "${DIR_PATH}/mi" ] || [ -f "${DIR_PATH}/md" ]; then
        echo "   ✅ 已完成或封裝 ➡️ 跳過。" >&2
        rm -f "$DIR_PATH/$MARKER_PRESENT"
        continue 
    fi

    echo "▶️  正在處理 $DIR_PATH" >&2
    
    # 2. 執行轉換
    DIR_FAILURE_FLAG=false # 使用一個布林標記取代臨時檔案
    
    # Find files and perform conversion
    # 使用 find -print0 遍歷目標資料夾內的原始圖片
while IFS= read -r -d $'\0' file; do
        
        # 轉換邏輯
        target_webp="${file%.*}.${TARGET_EXT}"
        
        # 檢查目標檔案是否已存在，並清理來源檔案
        if [ -f "$target_webp" ]; then
            if [ -f "$file" ]; then rm "$file"; fi
        else
            # 嘗試轉換
            if convert "$file" -quality "$QUALITY" "$target_webp"; then
                # 轉換成功後刪除原始檔案
                rm "$file"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') -  ❌ 資料夾: $DIR_PATH - 檔案: $(basename "$file") - 轉換失敗。" >> "$ERROR_LOG"
                DIR_FAILURE_FLAG=true # 設置目錄失敗標記
            fi
        fi
        
    done < <(find "$DIR_PATH" -maxdepth 1 -type f \( $FIND_FILTER_STRING \) -print0)
    
    # 3. 檢查目錄狀態並更新信標 (修改此處邏輯)
    if $DIR_FAILURE_FLAG; then
        # *** 變更點：轉換失敗時，將標記轉換為 mf ***
        echo "   ❌ 資料夾內有檔案轉換失敗，新增錯誤標記。" >&2
        # 移除舊標記
        rm -f "$DIR_PATH/$MARKER_PRESENT"
        # 新增 mf 標記 (Marker Failure)
        touch "$DIR_PATH/mf"
        echo "---" >&2
        
    else
        # 轉換成功
        # 修正：直接計算當前資料夾中 TARGET_EXT (webp) 檔案的數量
        SUCCESS_COUNT=$(find "$DIR_PATH" -maxdepth 1 -type f -iname "*.${TARGET_EXT}" | wc -l)
        
        echo "   ✅ 轉換成功，合計 $SUCCESS_COUNT 個檔案。" >&2
        
        # 信標轉換 (移除舊信標，新增新信標)
        rm -f "$DIR_PATH/$MARKER_PRESENT"
        touch "$DIR_PATH/$NEXT_MARKER"
        echo "---" >&2
    fi

done

echo "轉換作業完成。" >&2
echo "檔案轉換錯誤（若有的話）請查看 errorlog.txt。" >&2

exit 0