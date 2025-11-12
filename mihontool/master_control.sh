#!/bin/bash

# --- 配置參數 (確保這些腳本檔案存在於相同目錄) ---
RENAME_SCRIPT="./forcerename.sh"        # 步驟 1: 排序/更名
ACTIONMV_SCRIPT="./actionmove.sh"      # 步驟 2: 建立結構/複製封面/移動
CONVERT_SCRIPT="./auto_convert.sh"       # 步驟 3: 轉換 WebP
PACKAGE_SCRIPT="./pack_cbz.sh"           # 步驟 4: 封裝 CBZ

# 存儲所有報告結果的全局變數
REPORT_RENAME=""
REPORT_ACTIONMV=""
REPORT_CONVERT=""
REPORT_PACKAGE=""


# 函數：檢查子腳本權限
function check_and_set_permissions() {
    local scripts=("$RENAME_SCRIPT" "$ACTIONMV_SCRIPT" "$CONVERT_SCRIPT" "$PACKAGE_SCRIPT")
    local missing_scripts=()
    local chmod_required=false

    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ ! -x "$script" ]; then
                chmod +x "$script"
                chmod_required=true
            fi
        else
            missing_scripts+=("$script")
        fi
    done

    if [ ${#missing_scripts[@]} -gt 0 ]; then
        echo "🚨 錯誤：找不到以下關鍵腳本，無法繼續：" >&2
        for s in "${missing_scripts[@]}"; do
            echo " - $s" >&2
        done
        return 1
    fi
    if $chmod_required; then
        echo "✅ 偵測到權限不足，已自動新增執行權限 (chmod +x)。" >&2
    fi
    return 0
}

# 函數：執行腳本並捕捉結果
function run_and_capture() {
    local script_path="$1"
    local report_var_name="$2"
    
    # 執行腳本並捕獲 STDOUT
    # 關鍵修正：使用 $(...) 捕獲所有 STDOUT，然後用 | tail -n 1 提取最後一行
    # 這樣 REPORT_* 變數只會是 'S,F,T' 格式的單行字串
    local output
    if ! output=$(eval "\"$script_path\"" 2>&1); then
        # 如果子腳本執行失敗 (退出碼非 0)，則腳本輸出仍然會被捕獲，但我們知道它失敗了
        echo "🚨 腳本執行錯誤: $script_path (Exit Code $?)" >&2
        # 將捕獲到的輸出視為 STDOUT
    fi
    
    # 隔離最後一行報告 (S,F,T 格式)
    local last_line=$(echo "$output" | tail -n 1)
    
    # 將 S,F,T 報告存入全局變數
    eval "$report_var_name=\"$last_line\""

    # 必須確保子腳本的退出碼傳遞給 master_control
    return $?
}

# master_control.sh (完全修正版 show_final_report 函數)

function show_final_report() {
    echo "================================================="
    echo "      📊 最終批次處理報告 (Final Report) 📊"
    echo "================================================="

    # --- 步驟 1: 命名規範化 (forcerename.sh) ---
    if [ -n "$REPORT_RENAME" ]; then
        IFS=',' read -r S F T <<< "$REPORT_RENAME"
        
        # 修正：確保 S, F, T 變數不是空的，避免 [ : 需要整數表示式 錯誤
        S=${S:-0}
        F=${F:-0}
        T=${T:-0}
        
        # 決定狀態符號：如果失敗數 F > 0，則為 ❌；否則為 ✅
        STATUS_SYMBOL="✅"
        if [ "$F" -gt 0 ]; then
            STATUS_SYMBOL="❌"
        fi

        if [ "$T" -eq 0 ]; then
            REPORT_LINE="未找到需要命名的資料夾檔案。"
        elif [ "$F" -eq 0 ]; then
            REPORT_LINE="成功 ✅ 完成 $S 個資料夾的命名。"
        else
            REPORT_LINE="成功 $S 個，失敗 $F 個。請檢查錯誤日誌！"
        fi

        echo "📝 命名結果: ${STATUS_SYMBOL} $REPORT_LINE (總計 $T 個資料夾)"
    else
        echo "📝 命名結果: 未執行 ⚪"
    fi

    # --- 步驟 2: 結構建制 (actionmove.sh) ---
    if [ -n "$REPORT_ACTIONMV" ]; then
        IFS=',' read -r S F T <<< "$REPORT_ACTIONMV"
        
        # 修正：確保 S, F, T 變數不是空的
        S=${S:-0}
        F=${F:-0}
        T=${T:-0}

        # 決定狀態符號
        STATUS_SYMBOL="✅"
        if [ "$F" -gt 0 ]; then
            STATUS_SYMBOL="❌"
        fi

        if [ "$T" -eq 0 ]; then
            REPORT_LINE="未找到需要調整結構的資料夾。"
        elif [ "$F" -eq 0 ]; then
            REPORT_LINE="成功 ✅ 建制 $S 個資料夾的結構。"
        else
            REPORT_LINE="成功 $S 個，失敗 $F 個。請檢查錯誤日誌！"
        fi

        echo "📂 結構建制: ${STATUS_SYMBOL} $REPORT_LINE (總計 $T 個資料夾)"
    else
        echo "📂 結構建制: 未執行 ⚪"
    fi

    # --- 步驟 3: WebP 轉換 (auto_convert.sh) ---
    if [ -n "$REPORT_CONVERT" ]; then
        IFS=',' read -r S F T <<< "$REPORT_CONVERT"

        # 修正：確保 S, F, T 變數不是空的
        S=${S:-0}
        F=${F:-0}
        T=${T:-0}

        # 決定狀態符號
        STATUS_SYMBOL="✅"
        if [ "$F" -gt 0 ]; then
            STATUS_SYMBOL="❌"
        fi

        if [ "$T" -eq 0 ]; then
            REPORT_LINE="未找到任何需要轉換的檔案。  "
        elif [ "$F" -eq 0 ]; then
            REPORT_LINE="成功 ✅ 轉換 $S 個檔案。"
        else
            REPORT_LINE="成功 $S 個，失敗 $F 個。請檢查錯誤日誌！"
        fi

        echo "🖼️  檔案轉換: ${STATUS_SYMBOL} $REPORT_LINE (總計 $T 個檔案)"
    else
        echo "🖼️  檔案轉換: 未執行 ⚪"
    fi


    # --- 步驟 4: CBZ 封裝與清理 (pack_cbz.sh) ---
    if [ -n "$REPORT_PACKAGE" ]; then
        IFS=',' read -r S F T <<< "$REPORT_PACKAGE"

        # 修正：確保 S, F, T 變數不是空的
        S=${S:-0}
        F=${F:-0}
        T=${T:-0}
        
        # 決定狀態符號
        STATUS_SYMBOL="✅"
        if [ "$F" -gt 0 ]; then
            STATUS_SYMBOL="❌"
        fi

        if [ "$T" -eq 0 ]; then
            REPORT_LINE="未找到任何需要封裝的資料夾。"
        elif [ "$F" -eq 0 ]; then
            REPORT_LINE="成功 ✅ 完成 $S 個封裝，並已清理原始資料。"
        else
            REPORT_LINE="完成 $S 個封裝，但有 $F 個失敗/清理失敗。請檢查錯誤日誌！"
        fi
        
        echo "📦 壓縮封裝: ${STATUS_SYMBOL} $REPORT_LINE (總計 $T 個資料夾)"
    else
        echo "📦 壓縮封裝: 未執行 ⚪"
    fi

    echo "-------------------------------------------------"
}

# 函數：清理舊日誌
function clean_logs() {
    # 刪除所有前綴為腳本名稱的日誌檔
    find . -maxdepth 1 -type f -name '*_errors_*.log' -delete 2>/dev/null
    find . -maxdepth 1 -type f -name 'temp_*_success_log_*' -delete 2>/dev/null
    
    # 重置全局變數
    REPORT_RENAME=""
    REPORT_ACTIONMV=""
    REPORT_CONVERT=""
    REPORT_PACKAGE=""
}

# 函數：確認執行
function confirm_action() {
    local action_desc="$1"
    local command_to_execute="$2"
    
    echo -n "⚠️ 確定要 $action_desc 嗎? [Y/N 或 y/n]: " >&2
    read -r confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        eval "$command_to_execute"
        return $?
    fi
    return 1
}

# --- 流程定義 ---

# 流程 1: 預備工作流程 (Naming -> Structure -> Convert)
function run_prep_workflow() {
    clean_logs
    
    REPORT_RENAME=""
    REPORT_ACTIONMV=""
    REPORT_CONVERT=""
    
    echo "--- 執行工作流程一： (命名 -> 建構 -> 轉換) ---" >&2

    # 步驟 1: 命名規範化 (forcerename.sh) - 失敗發出警告並繼續 (Continue on Error)
    echo "--- 執行 標準格式命名 ($RENAME_SCRIPT)..." >&2
    if ! run_and_capture "$RENAME_SCRIPT" REPORT_RENAME; then
        echo "⚠️ 警告：命名階段發生部分失敗或跳過。**繼續執行下一階段**，請檢查日誌。" >&2
    fi

    # 步驟 2: 建制結構 (actionmove.sh) - 失敗即中止 (Fail Fast)
    echo "--- 執行 建制結構主體 ($ACTIONMV_SCRIPT)..." >&2
    if ! run_and_capture "$ACTIONMV_SCRIPT" REPORT_ACTIONMV; then
        echo "❌ 嚴重錯誤：建制結構階段偵測到失敗，**強制中止流程**。請檢查 $ACTIONMV_SCRIPT 產生的日誌。" >&2
        show_final_report
        return 1
    fi
    
    # 步驟 3: WebP 轉換 (auto_convert.sh) - 失敗即中止 (Fail Fast)
    echo "--- 執行 WebP 轉換 ($CONVERT_SCRIPT)..." >&2
    if ! run_and_capture "$CONVERT_SCRIPT" REPORT_CONVERT; then
        echo "❌ 嚴重錯誤：WebP 轉換階段偵測到失敗檔案，**強制中止流程**。請檢查 $CONVERT_SCRIPT 產生的日誌。" >&2
        show_final_report
        return 1
    fi
    
    echo "--- 工作流程一執行完畢，顯示最終報告 ---" >&2
    show_final_report
    return 0
}


# 流程 2: 完整標準工作流程 (Naming -> Structure -> Convert -> Package)
function run_full_workflow() {
    clean_logs
    
    REPORT_RENAME=""
    REPORT_ACTIONMV=""
    REPORT_CONVERT=""
    REPORT_PACKAGE=""
    
    echo "--- 執行工作流程二： (命名 -> 建構 -> 轉換 -> 封裝) ---" >&2

    # 步驟 1: 命名規範化 (forcerename.sh) - 失敗發出警告並繼續 (Continue on Error)
    echo "--- 執行 標準格式命名 ($RENAME_SCRIPT)..." >&2
    if ! run_and_capture "$RENAME_SCRIPT" REPORT_RENAME; then
        echo "⚠️ 警告：命名階段發生部分失敗或跳過。**繼續執行下一階段**，請檢查日誌。" >&2
    fi

    # 步驟 2: 建制結構 (actionmove.sh) - 失敗即中止 (Fail Fast)
    echo "--- 執行 建制結構主體 ($ACTIONMV_SCRIPT)..." >&2
    if ! run_and_capture "$ACTIONMV_SCRIPT" REPORT_ACTIONMV; then
        echo "❌ 嚴重錯誤：建制結構階段偵測到失敗，**強制中止流程**。請檢查 $ACTIONMV_SCRIPT 產生的日誌。" >&2
        show_final_report
        return 1
    fi
    
    # 步驟 3: WebP 轉換 (auto_convert.sh) - 失敗即中止 (Fail Fast)
    echo "--- 執行 WebP 轉換 ($CONVERT_SCRIPT)..." >&2
    if ! run_and_capture "$CONVERT_SCRIPT" REPORT_CONVERT; then
        echo "❌ 嚴重錯誤：WebP 轉換階段偵測到失敗檔案，**強制中止流程**。請檢查 $CONVERT_SCRIPT 產生的日誌。" >&2
        show_final_report
        return 1
    fi
    
    # 步驟 4: CBZ 封裝 (pack_cbz.sh) - 失敗發出警告並繼續 (Continue on Error for final step)
    echo "--- 執行 CBZ 封裝與清理 ($PACKAGE_SCRIPT)..." >&2
    if ! run_and_capture "$PACKAGE_SCRIPT" REPORT_PACKAGE; then
        echo "⚠️ 警告：CBZ 封裝階段發生部分失敗或跳過 (Exit 1)。流程結束，請檢查日誌。" >&2
    fi
    
    echo "--- 工作流程二執行完畢，顯示最終報告 ---" >&2
    show_final_report
    return 0
}


# --- 主選單邏輯 ---

while true; do
    # 避免誤刪，將標準輸出重導向到文件描述符 3，只輸出到終端機
    exec 3>&1 
    
    echo ""
    echo "=================================================" >&2
    echo "          🧰 批次漫畫處理 Master Control 🧰" >&2
    echo "=================================================" >&2
    echo " 請選擇要執行的流程：" >&2
    echo " 1. 工作流程一 (更名 -> 建構 -> 轉換)" >&2
    echo " 2. 工作流程二 (更名 -> 建構 -> 轉換 -> 封裝)" >&2
    echo " -----------------------------------------------" >&2
    echo " 3. 執行標準化命名 (image_001.ext, image_n.ext...)" >&2
    echo " 4. 建立結構主體 (建制 chapter_1 資料夾及 cover.ext 封面結構)" >&2
    echo " 5. 執行 WebP 轉換 (將任意圖片檔轉換 webp 格式)" >&2
    echo " 6. 執行 CBZ 封裝與清理 (只封裝 chapter_1 資料夾)" >&2
    echo " 7. 主動清理輸出日誌" >&2
    echo " -----------------------------------------------" >&2
    echo " 0. 退出" >&2
    echo " -----------------------------------------------" >&2
    
    # 確保所有腳本都存在且有執行權限
    if ! check_and_set_permissions; then
        read -r -p "按 Enter 鍵退出..."
        exit 1
    fi

    echo -n "請輸入選項 [0-6]: " >&2
    read -r choice

    case "$choice" in
        1)
            # 流程 1: 預備工作流程 (不封裝)
            run_prep_workflow
            ;;
        2)
            # 流程 2: 完整標準流程 (含封裝)
            run_full_workflow
            ;;
        3)
            # 流程 3: 僅 命名規範化
            clean_logs 
            REPORT_RENAME=""
            if confirm_action "執行 標準格式命名 ($RENAME_SCRIPT)" "run_and_capture \\\"$RENAME_SCRIPT\\\" REPORT_RENAME"; then
                 echo "已完成標準格式命名。請檢查上方報告及錯誤日誌！" >&2
            fi
            show_final_report
            ;;
        4)
            # 流程 4: 僅 建制結構主體
            clean_logs 
            REPORT_ACTIONMV=""
            if confirm_action "建制 cover.ext 及 chapter_1 結構主體 ($ACTIONMV_SCRIPT)" "run_and_capture \\\"$ACTIONMV_SCRIPT\\\" REPORT_ACTIONMV"; then
                 echo "結構主體已建制完成。請檢查上方報告及錯誤日誌！" >&2
            fi
            show_final_report
            ;;
        5)
            # 流程 5: 僅 WebP 轉換
            clean_logs 
            REPORT_CONVERT=""
            if confirm_action "執行 WebP 轉換 ($CONVERT_SCRIPT)" "run_and_capture \\\"$CONVERT_SCRIPT\\\" REPORT_CONVERT"; then
                 echo "已完成 WebP 轉換。請檢查上方報告及錯誤日誌！" >&2
            fi
            show_final_report
            ;;
        6)
            # 流程 6: 僅 CBZ 封裝
            clean_logs 
            REPORT_PACKAGE=""
            if confirm_action "執行 CBZ 封裝與清理 ($PACKAGE_SCRIPT)" "run_and_capture \\\"$PACKAGE_SCRIPT\\\" REPORT_PACKAGE"; then
                 echo "CBZ 封裝完成。請檢查上方報告及錯誤日誌！" >&2
            fi
            show_final_report
            ;;
        7)
            # 流程 7: 清理日誌
            clean_logs 
            ;;
        0)
            # 退出
            echo "程序已退出。" >&2
            exit 0
            ;;
        *)
            echo "無效的選項，請重新輸入。" >&2
            ;;
    esac
done