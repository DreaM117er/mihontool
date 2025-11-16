#!/bin/bash

# --- 配置參數 ---
PACK_EXT="cbz"
ERROR_LOG="errorlog.txt"
CBZ_OUTPUT_DIR="$PWD" 
TEMP_SUCCESS_LOG="temp_success_log_$$"

echo "---" >&2
echo "執行多章節結構封裝 (.cbz) ..." >&2

# 1. 計算總資料夾數 (只計算包含 mi 信標的資料夾)
TOTAL_DIRS=$(find . -mindepth 1 -maxdepth 1 -type d -exec test -f "{}/mi" \; -print | wc -l)

if [ "$TOTAL_DIRS" -eq 0 ]; then
    echo "未找到任何帶有 'mi' 標記的資料夾需要封裝，腳本執行完畢。" >&2
    exit 0
fi

echo "總共有 $TOTAL_DIRS 個資料夾需要處理。" >&2
echo "---" >&2

> "$TEMP_SUCCESS_LOG"

# --- 核心邏輯：find -print0 | while read 處理特殊字元 ---

find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d $'\0' DIR_PATH; do
    
    # --- 關鍵檢查：只處理有 mi 信標的資料夾 ---
    if [ ! -f "$DIR_PATH/mi" ]; then
        continue # 沒有 mi 信標，跳過。
    fi
    
    # --- 安全檢查：如果已經有 md 信標，跳過 ---
    if [ -f "$DIR_PATH/md" ]; then
        echo "➡️ $DIR_PATH: 已有 'md' 標記，跳過。" >&2
        [ -f "$DIR_PATH/mi" ] && rm "$DIR_PATH/mi"
        continue
    fi
    # ----------------------------------------------------
    
    echo "▶️  正在處理 $DIR_PATH" >&2

    # ---
    # (新邏輯) 需求 2: 檢查衝突 (同時存在 chapter_n 資料夾和 chapter_n.cbz)
    # ---
    
    # (!!修正!!) 移除 'local'
    HAS_CONFLICT=0
    
    # 遍歷所有 chapter_n "資料夾"
    while IFS= read -r -d $'\0' chap_dir; do
        # (!!修正!!) 移除 'local'
        base_name=$(basename "$chap_dir")
        
        # 檢查同名的 .cbz 是否存在
        if [ -f "$DIR_PATH/${base_name}.${PACK_EXT}" ]; then
            HAS_CONFLICT=1
            echo "   ❌ 結構衝突: $base_name (資料夾) 和 ${base_name}.${PACK_EXT} (壓縮檔) 同時存在。" >&2
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $DIR_PATH - 結構衝突: $base_name" >> "$ERROR_LOG"
            break
        fi
    done < <(find "$DIR_PATH" -maxdepth 1 -type d -iname "chapter_*" -print0)

    # (!!修正!!) 這裡 "$HAS_CONFLICT" 現在會是 0 或 1 (不再是空字串)
    if [ "$HAS_CONFLICT" -eq 1 ]; then
        # 偵測到衝突，標記 mf 並跳到下一個資料夾
        echo "   ❌ 標記 mf 並中止此資料夾處理。" >&2
        rm -f "$DIR_PATH/mi" "$DIR_PATH/m3" # 移除 mi 或 m3
        touch "$DIR_PATH/mf"
        echo "---" >&2
        continue # 處理下一個 DIR_PATH
    fi
    
    # ---
    # (新邏輯) 需求 1, 3, 4: 封裝所有找到的 chapter_n 資料夾
    # ---
    
    # 找出所有 chapter_n 資料夾 (確保至少有一個)
    CHAPTERS_FOUND_COUNT=$(find "$DIR_PATH" -maxdepth 1 -type d -iname "chapter_*" | wc -l)
    if [ "$CHAPTERS_FOUND_COUNT" -eq 0 ]; then
        echo "   ⚠️  $DIR_PATH: 標記為 'mi' 但未找到任何 'chapter_n' 資料夾，跳過。" >&2
        echo "---" >&2
        continue
    fi
    
    # (!!修正!!) 移除 'local'
    PACK_SUCCESS=true
    # (!!修正!!) 移除 'local'
    CHAPTER_PACKED_COUNT=0
    
    # 再次遍歷 (這次是真的要打包)
    while IFS= read -r -d $'\0' CHAP_DIR_PATH; do
        # (!!修正!!) 移除 'local'
        CHAP_BASE=$(basename "$CHAP_DIR_PATH")
        
        # 封裝 CBZ：將工作目錄切換到 chapter_n，打包內部所有檔案
        # (使用相對路徑 ../ 確保 CBZ 檔案在 $DIR_PATH 中)
        # (!!修正!!) 移除 'local'
        CBZ_OUTPUT_REL_PATH="../${CHAP_BASE}.${PACK_EXT}"
        
        if (cd "$CHAP_DIR_PATH" && zip -0 -r "$CBZ_OUTPUT_REL_PATH" . -x "*.cbz" > /dev/null 2>&1); then
            
            # 封裝成功，刪除原始資料夾
            if rm -rf "$CHAP_DIR_PATH"; then
                echo "   ✅ 封裝 $CHAP_BASE 成功，已刪除來源資料夾。" >&2
                CHAPTER_PACKED_COUNT=$((CHAPTER_PACKED_COUNT + 1))
            else
                echo "   ❌ 封裝 $CHAP_BASE 成功，但刪除 $CHAP_DIR_PATH 失敗。" >&2
                echo "$(date '+%Y-%m-%d %H:%M:%S') - $DIR_PATH - 刪除 $CHAP_BASE 失敗" >> "$ERROR_LOG"
                PACK_SUCCESS=false
                break # 刪除失敗是嚴重問題，停止處理此系列
            fi
        else
            echo "   ❌ 封裝 $CHAP_BASE 失敗 (壓縮檔錯誤)。" >&2
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $DIR_PATH - 封裝 $CHAP_BASE 失敗" >> "$ERROR_LOG"
            PACK_SUCCESS=false
            break # 封裝失敗，停止處理此系列
        fi

    done < <(find "$DIR_PATH" -maxdepth 1 -type d -iname "chapter_*" -print0)
    
    # ---
    # (新邏輯) 最終標記
    # ---
    
    # (!!修正!!) 'if $PACK_SUCCESS' 應改為 'if [ "$PACK_SUCCESS" = "true" ]'
    # 這樣更健壯，避免 $PACK_SUCCESS 為空時 'if ;' 造成的問題
    if [ "$PACK_SUCCESS" = "true" ]; then
        echo "      封裝成功 $CHAPTER_PACKED_COUNT / $CHAPTERS_FOUND_COUNT 個章節。" >&2
        
        # 移除 mi 信標並新增 md (代表此系列已是 .cbz 結構)
        rm -f "$DIR_PATH/mi"
        touch "$DIR_PATH/md"
        echo "success" >> "$TEMP_SUCCESS_LOG" # 記錄成功
    else
        # 如果 $PACK_SUCCESS=false (中途失敗)
        rm -f "$DIR_PATH/mi"
        touch "$DIR_PATH/mf"
    fi
    
    echo "---" >&2

done

# --- 最終統計 (移除資料捕捉數字輸出) ---
SUCCESS_COUNT=$(wc -l < "$TEMP_SUCCESS_LOG")
FAILURE_COUNT=$(wc -l < "$ERROR_LOG")

# 清理臨時檔案
rm "$TEMP_SUCCESS_LOG" 2>/dev/null

if [ "$FAILURE_COUNT" -gt 0 ]; then
    echo "🚨 封裝失敗共 $FAILURE_COUNT 個，請檢查 errorlog.txt。" >&2
    exit 1 
fi

echo "資料夾封裝作業已全數完成。" >&2
if [ "$SUCCESS_COUNT" -gt 0 ] || [ "$FAILURE_COUNT" -gt 0 ]; then
    echo "請檢查 errorlog.txt 以查看錯誤詳情。" >&2
fi

exit 0