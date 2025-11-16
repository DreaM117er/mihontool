#!/bin/bash
# master_control.sh - 漫畫批次處理主控臺腳本 (Master Controller) v3.1

# --- 1. 配置與初始化 ---
# 腳本列表 (請確保這些檔案與 master_control.sh 在同一目錄下)
SCRIPT_LIST=(
    "autoconvert.sh"
    "forcerename.sh"
    "actionmove.sh"
    "packcbz.sh"
    "folderstate.sh"
    "markdown.sh"
    "covercheck.sh"
)

# 核心腳本定義
CONVERT_SCRIPT="autoconvert.sh"
RENAME_SCRIPT="forcerename.sh"
ACTION_MOVE_SCRIPT="actionmove.sh"
PACK_CBZ_SCRIPT="packcbz.sh"
FOLDER_STATE_SCRIPT="folderstate.sh" # 資料夾狀態檢查
MARKDOWN_SCRIPT="markdown.sh"       # 核心信標掃描
F_RENAME_SCRIPT="covercheck.sh"        # m3/單圖處理 (信標檢查的最後一步)

echo "---" >&2
echo "執行漫畫批次處理主控台前置作業。" >&2
echo "---" >&2

# --- 2. 函數定義 ---

# 設置腳本執行權限
function set_permissions() {
    echo "正在檢查並設置所有功能的執行權限..." >&2
    echo "---" >&2
    local count=0
    for script in "${SCRIPT_LIST[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            echo " ✅ 腳本 $script 權限已設置。" >&2
            count=$((count + 1))
        else
            echo " ❌ 腳本 $script 找不到，請檢查腳本是否存在。" >&2
        fi
    done
    echo "---" >&2
    echo "首次啓動執行檢查結果會在下一次選擇項目時清除。" >&2
    echo "---" >&2
    echo "" >&2
}

# 清除歷史日誌檔案
function clean_logs() {
    echo "正在清除日誌檔案 errorlog.txt 內的歷史資料..." >&2
    
    # 刪除所有功能腳本可能產生的日誌檔案
    # 根據提供的腳本片段，日誌檔名包含: *_errors_*.log, temp_*.log, temp_*.txt
    find . -maxdepth 1 -type f \( -name "errorlog.txt" \) -delete
    echo "---" >&2
    echo " ✅ 日誌清理完成。" >&2
    echo "---" >&2
}

# 執行主要轉換腳本前的「標記與檢查」預處理
function pre_process_check() {
    > errorlog.txt
    # 步驟 1: 執行 MARKDOWN_SCRIPT (核心信標掃描)
    if [ -f "$MARKDOWN_SCRIPT" ]; then
        echo "▶️  啓動 ${MARKDOWN_SCRIPT} 腳本..." >&2
        ./"$MARKDOWN_SCRIPT"
        echo "---" >&2
        echo "✅ ${MARKDOWN_SCRIPT} 執行完成。" >&2
        echo "---" >&2
    else
        echo "---" >&2
        echo "❌ 錯誤：找不到 ${MARKDOWN_SCRIPT}，跳過執行。" >&2
        echo "---" >&2
    fi
    
    # 步驟 2: 執行 F_RENAME_SCRIPT (單圖命名/檢查結構完整性)
    if [ -f "$F_RENAME_SCRIPT" ]; then
        echo "▶️  啓動 ${F_RENAME_SCRIPT} 腳本..." >&2
        ./"$F_RENAME_SCRIPT"
        echo "---" >&2
        echo "✅ ${F_RENAME_SCRIPT} 執行完成。" >&2
    else
        echo "---" >&2
        echo "❌ 錯誤：找不到 ${F_RENAME_SCRIPT}！" >&2
    fi
}

# 帶有 Y/N 確認的執行函數
function execute_with_confirm() {
    local option_name="$1"
    local scripts_to_run=("$@")
    read -r -p "❓ 確認執行 ${option_name} 嗎？ (Y/N 或 y/n): " response
    echo "---" >&2
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # 標準流程和單獨執行流程，需先執行預處理
        if [ "$option_name" != "資料夾狀態" ]; then
            pre_process_check
        fi
        # 移除第一個參數 (option_name)，只留下腳本清單
        local i=0
        for script in "${scripts_to_run[@]}"; do
            if [ "$i" -gt 0 ]; then
                if [ -f "$script" ]; then
                    echo "---" >&2
                    echo "▶️  啓動 ${script} 腳本..." >&2
                    ./"$script"
                    if [ $? -ne 0 ]; then
                        echo "⚠️  ${script} 執行失敗，流程中斷。" >&2
                        return 1
                    fi
                else
                    echo "❌ 錯誤：找不到 $script，流程中斷。" >&2
                    return 1
                fi
            fi
            i=$((i+1))
        done
        return 0
    else
        echo "操作已取消。" >&2
        return 1
    fi
}

# 顯示選單
function display_menu() {
    echo "=================================================="
    echo "  📚 漫畫批次處理主控台 (Master Control) v3.1"
    echo "=================================================="
    echo "1. 資料夾狀態"
    echo "2. 資料夾標記及檢查"
    echo "---"
    echo "3. 完整結構主體調整流程：標記 -> 檢查 -> 轉檔 -> 命名 -> 結構"
    echo "4. 完整結構主體封裝流程：標記 -> 檢查 -> 轉檔 -> 命名 -> 結構 -> 封裝"
    echo "---"
    echo "5. 執行 webp 轉換"
    echo "6. 執行 標準化命名"
    echo "7. 創建 chapter_1 主體結構"
    echo "8. 執行 chapter_n 主體封裝"
    echo "---"
    echo "9. 主動清除日誌及暫存檔案"
    echo "0. 關閉主控臺"
    echo "---"
    read -r -p "💻 輸入數字 0-9 來選擇執行項目: " CHOICE
    echo "---"
}


# --- 3. 腳本主體 ---
clean_logs
# 步驟 1: 清理日誌 (新增步驟)


# 步驟 2: 設置權限
set_permissions

# 步驟 3: 進入主迴圈
while true; do
    display_menu
    
    case $CHOICE in
        # 選項 1: 資料夾狀態 (單獨執行 folderstate.sh，不需要 Y/N 確認)
        1)
            echo "當前資料夾狀態" >&2
            echo "---" >&2
            ./"$FOLDER_STATE_SCRIPT"
            echo "---"
            ;;
            
        # 選項 2: 資料夾標記及檢查 (執行預處理，不需要 Y/N 確認)
        2)
            pre_process_check
            echo "---" >&2
            echo "確認資料夾狀態..." >&2
            echo "---" >&2
            ./"$FOLDER_STATE_SCRIPT"
            echo "---"
            ;;
        
        # 流程一：需要 Y/N 確認，並在 execute_with_confirm 內部執行預處理
        3)
            execute_with_confirm "完整結構主體調整流程" \
                "$CONVERT_SCRIPT" \
                "$RENAME_SCRIPT" \
                "$ACTION_MOVE_SCRIPT"
            echo "---"
            ;;

        # 流程二：需要 Y/N 確認，並在 execute_with_confirm 內部執行預處理
        4)
            execute_with_confirm "完整結構主體封裝流程" \
                "$CONVERT_SCRIPT" \
                "$RENAME_SCRIPT" \
                "$ACTION_MOVE_SCRIPT" \
                "$PACK_CBZ_SCRIPT"
            echo "---"
            ;;

        # 單獨執行：轉檔
        5)
            execute_with_confirm "webp 轉換" \
                "$CONVERT_SCRIPT"
            echo "---"
            ;;

        # 單獨執行：命名 (只包含 forcerename.sh)
        6)
            execute_with_confirm "標準化命名" \
                "$RENAME_SCRIPT"
            echo "---"
            ;;

        # 單獨執行：結構調整
        7)
            execute_with_confirm "chapter_1 主體結構建立" \
                "$ACTION_MOVE_SCRIPT"
            echo "---"
            ;;

        # 單獨執行：封裝
        8)
            execute_with_confirm "chapter_1 主體結構封裝" \
                "$PACK_CBZ_SCRIPT"
            echo "---"
            ;;

        9)
            clean_logs
            ;;

        # 離開選項
        0)
            clear
            echo "已關閉漫畫批次處理主控台，下次再見。" >&2
            exit 0
            ;;
            
        *)
            echo "無效輸入，請再輸入一次。" >&2
            echo "---"
            sleep 1
            ;;
    esac

    read -r -p "按 Enter 清除當前結果並繼續執行流程項目..."
    clear
done
