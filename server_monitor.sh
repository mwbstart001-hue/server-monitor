#!/bin/bash

SERVER_NAME=$(hostname)
SAMPLE_COUNT=5
INTERVAL=1

is_valid_number() {
    local value="$1"
    if [[ -z "$value" ]]; then
        return 1
    fi
    if [[ "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

is_greater_than_zero() {
    local value="$1"
    if ! is_valid_number "$value"; then
        return 1
    fi
    
    local result=$(echo "$value" | awk '{if ($1 > 0) print "yes"; else print "no"}')
    if [ "$result" = "yes" ]; then
        return 0
    else
        return 1
    fi
}

compare_numbers() {
    local a="$1"
    local op="$2"
    local b="$3"
    
    if ! is_valid_number "$a" || ! is_valid_number "$b"; then
        echo "false"
        return
    fi
    
    local result=$(echo | awk -v a="$a" -v b="$b" -v op="$op" '
        {
            if (op == "gt") result = (a > b)
            else if (op == "lt") result = (a < b)
            else if (op == "ge") result = (a >= b)
            else if (op == "le") result = (a <= b)
            else if (op == "eq") result = (a == b)
            else result = 0
            if (result) print "true"
            else print "false"
        }
    ')
    echo "$result"
}

is_less_than() {
    local a="$1"
    local b="$2"
    local result=$(compare_numbers "$a" "lt" "$b")
    if [ "$result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

is_greater_than() {
    local a="$1"
    local b="$2"
    local result=$(compare_numbers "$a" "gt" "$b")
    if [ "$result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

safe_divide() {
    local dividend="$1"
    local divisor="$2"
    local default="${3:-0}"
    
    if ! is_valid_number "$dividend" || ! is_valid_number "$dividend"; then
        echo "$default"
        return
    fi
    
    if ! is_greater_than_zero "$divisor"; then
        echo "$default"
        return
    fi
    
    echo "$dividend $divisor" | awk '{printf "%.2f", $1 / $2}'
}

safe_multiply() {
    local a="$1"
    local b="$2"
    local default="${3:-0}"
    
    if ! is_valid_number "$a" || ! is_valid_number "$b"; then
        echo "$default"
        return
    fi
    
    echo "$a $b" | awk '{printf "%.2f", $1 * $2}'
}

bytes_to_gb() {
    local bytes="$1"
    local default="${2:-0}"
    
    if ! is_valid_number "$bytes"; then
        echo "$default"
        return
    fi
    
    echo "$bytes" | awk '{printf "%.2f", $1 / 1024 / 1024 / 1024}'
}

calc_average() {
    local count=0
    local sum=0
    
    for value in "$@"; do
        if is_valid_number "$value"; then
            count=$((count + 1))
            sum=$(echo "$sum $value" | awk '{printf "%.4f", $1 + $2}')
        fi
    done
    
    if [ "$count" -eq 0 ]; then
        echo "0.00"
        return
    fi
    
    safe_divide "$sum" "$count" "0.00"
}

calc_min() {
    local first=true
    local min=""
    
    for value in "$@"; do
        if is_valid_number "$value"; then
            if [ "$first" = true ]; then
                min="$value"
                first=false
            else
                if is_less_than "$value" "$min"; then
                    min="$value"
                fi
            fi
        fi
    done
    
    if [ "$first" = true ]; then
        echo "0.00"
    else
        echo "$min" | awk '{printf "%.2f", $1}'
    fi
}

calc_max() {
    local first=true
    local max=""
    
    for value in "$@"; do
        if is_valid_number "$value"; then
            if [ "$first" = true ]; then
                max="$value"
                first=false
            else
                if is_greater_than "$value" "$max"; then
                    max="$value"
                fi
            fi
        fi
    done
    
    if [ "$first" = true ]; then
        echo "0.00"
    else
        echo "$max" | awk '{printf "%.2f", $1}'
    fi
}

calc_range() {
    local min="$1"
    local max="$2"
    local default="${3:-0}"
    
    if ! is_valid_number "$min" || ! is_valid_number "$max"; then
        echo "$default"
        return
    fi
    
    echo "$max $min" | awk '{printf "%.2f", $1 - $2}'
}

calc_percent() {
    local part="$1"
    local total="$2"
    local default="${3:-0}"
    
    if ! is_greater_than_zero "$total"; then
        echo "$default"
        return
    fi
    
    if ! is_valid_number "$part"; then
        echo "$default"
        return
    fi
    
    echo "$part $total" | awk '{printf "%.1f", ($1 / $2) * 100}'
}

format_number() {
    local value="$1"
    local decimals="${2:-2}"
    local default="${3:-0.00}"
    
    if ! is_valid_number "$value"; then
        echo "$default"
        return
    fi
    
    echo "$value" | awk -v dec="$decimals" '{printf "%." dec "f", $1}'
}

check_command() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

echo "=============================================="
echo "      服务器资源监控信息采集脚本"
echo "=============================================="
echo "服务器名称: $SERVER_NAME"
echo "采集时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "采集次数: $SAMPLE_COUNT 次"
echo "采集间隔: $INTERVAL 秒"
echo "=============================================="
echo ""

echo "[检查] 验证系统命令可用性..."
required_commands=("awk" "grep" "cut" "sleep" "hostname")
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if ! check_command "$cmd"; then
        missing_commands+=("$cmd")
    fi
done

if [[ "$OSTYPE" == "darwin"* ]]; then
    macos_commands=("top" "sysctl" "vm_stat")
    for cmd in "${macos_commands[@]}"; do
        if ! check_command "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
else
    linux_commands=("top" "free")
    for cmd in "${linux_commands[@]}"; do
        if ! check_command "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
fi

if [ ${#missing_commands[@]} -gt 0 ]; then
    echo "[错误] 缺少必要的系统命令: ${missing_commands[*]}"
    echo "请安装这些命令后再运行此脚本。"
    exit 1
fi

echo "[检查] 所有必要命令都已就绪。"
echo ""

cpu_usage_list=()
mem_total_list=()
mem_used_list=()
mem_free_list=()

successful_samples=0
failed_samples=0

get_system_info() {
    local cpu_usage=""
    local mem_total_gb=""
    local mem_used_gb=""
    local mem_free_gb=""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local top_output=$(top -l 2 -n 0 2>&1)
        if [ $? -eq 0 ]; then
            local cpu_line=$(echo "$top_output" | grep 'CPU usage' | tail -n 1)
            if [ -n "$cpu_line" ]; then
                local user=$(echo "$cpu_line" | awk '{print $3}' | tr -d '%')
                local sys=$(echo "$cpu_line" | awk '{print $5}' | tr -d '%')
                
                if is_valid_number "$user" && is_valid_number "$sys"; then
                    cpu_usage=$(echo "$user $sys" | awk '{printf "%.1f", $1 + $2}')
                fi
            fi
        fi
        
        local mem_total_bytes=$(sysctl -n hw.memsize 2>&1)
        if [ $? -eq 0 ] && is_valid_number "$mem_total_bytes"; then
            mem_total_gb=$(bytes_to_gb "$mem_total_bytes" "")
        fi
        
        local vm_stat_output=$(vm_stat 2>&1)
        if [ $? -eq 0 ]; then
            local page_size=$(sysctl -n hw.pagesize 2>&1)
            if [ $? -eq 0 ] && is_valid_number "$page_size"; then
                local free_pages=$(echo "$vm_stat_output" | grep 'Pages free' | awk '{print $3}' | tr -d '.')
                local active_pages=$(echo "$vm_stat_output" | grep 'Pages active' | awk '{print $3}' | tr -d '.')
                local inactive_pages=$(echo "$vm_stat_output" | grep 'Pages inactive' | awk '{print $3}' | tr -d '.')
                local speculative_pages=$(echo "$vm_stat_output" | grep 'Pages speculative' | awk '{print $3}' | tr -d '.')
                local wired_pages=$(echo "$vm_stat_output" | grep 'Pages wired down' | awk '{print $4}' | tr -d '.')
                local compressed_pages=$(echo "$vm_stat_output" | grep 'Pages occupied by compressor' | awk '{print $5}' | tr -d '.')
                
                if is_valid_number "$free_pages" && is_valid_number "$page_size"; then
                    local free_bytes=$((free_pages * page_size)) 2>/dev/null
                    if [ $? -eq 0 ] && is_valid_number "$free_bytes"; then
                        mem_free_gb=$(bytes_to_gb "$free_bytes" "")
                    fi
                fi
                
                if is_valid_number "$active_pages" && is_valid_number "$inactive_pages" && \
                   is_valid_number "$speculative_pages" && is_valid_number "$wired_pages" && \
                   is_valid_number "$compressed_pages" && is_valid_number "$page_size"; then
                    
                    local used_pages=$((active_pages + inactive_pages + speculative_pages + wired_pages + compressed_pages)) 2>/dev/null
                    if [ $? -eq 0 ] && is_valid_number "$used_pages"; then
                        local used_bytes=$((used_pages * page_size)) 2>/dev/null
                        if [ $? -eq 0 ] && is_valid_number "$used_bytes"; then
                            mem_used_gb=$(bytes_to_gb "$used_bytes" "")
                        fi
                    fi
                fi
            fi
        fi
        
        if [ -z "$mem_used_gb" ] && [ -n "$mem_total_gb" ] && [ -n "$mem_free_gb" ]; then
            mem_used_gb=$(echo "$mem_total_gb $mem_free_gb" | awk '{printf "%.2f", $1 - $2}')
        elif [ -z "$mem_free_gb" ] && [ -n "$mem_total_gb" ] && [ -n "$mem_used_gb" ]; then
            mem_free_gb=$(echo "$mem_total_gb $mem_used_gb" | awk '{printf "%.2f", $1 - $2}')
        fi
        
    else
        local top_output=$(top -bn2 -d0.1 2>&1)
        if [ $? -eq 0 ]; then
            local cpu_line=$(echo "$top_output" | grep 'Cpu(s)' | tail -n 1)
            if [ -n "$cpu_line" ]; then
                local user=$(echo "$cpu_line" | awk -F'[ ,]+' '{print $2}')
                local sys=$(echo "$cpu_line" | awk -F'[ ,]+' '{print $4}')
                
                if is_valid_number "$user" && is_valid_number "$sys"; then
                    cpu_usage=$(echo "$user $sys" | awk '{printf "%.1f", $1 + $2}')
                fi
            fi
        fi
        
        local mem_output=$(free -m 2>&1)
        if [ $? -eq 0 ]; then
            local mem_info=$(echo "$mem_output" | grep 'Mem')
            if [ -n "$mem_info" ]; then
                local mem_total_mb=$(echo "$mem_info" | awk '{print $2}')
                local mem_used_mb=$(echo "$mem_info" | awk '{print $3}')
                local mem_free_mb=$(echo "$mem_info" | awk '{print $4 + $6 + $7}')
                
                if is_valid_number "$mem_total_mb"; then
                    mem_total_gb=$(safe_divide "$mem_total_mb" "1024" "")
                fi
                
                if is_valid_number "$mem_used_mb"; then
                    mem_used_gb=$(safe_divide "$mem_used_mb" "1024" "")
                fi
                
                if is_valid_number "$mem_free_mb"; then
                    mem_free_gb=$(safe_divide "$mem_free_mb" "1024" "")
                fi
            fi
        fi
    fi
    
    echo "$cpu_usage|$mem_total_gb|$mem_used_gb|$mem_free_gb"
}

echo "开始采集数据..."
echo "----------------------------------------------"

for ((i=1; i<=SAMPLE_COUNT; i++)); do
    info=$(get_system_info)
    cpu_usage=$(echo "$info" | cut -d'|' -f1)
    mem_total=$(echo "$info" | cut -d'|' -f2)
    mem_used=$(echo "$info" | cut -d'|' -f3)
    mem_free=$(echo "$info" | cut -d'|' -f4)
    
    sample_valid=true
    
    if ! is_valid_number "$cpu_usage"; then
        sample_valid=false
        cpu_usage="N/A"
    fi
    
    if ! is_valid_number "$mem_total"; then
        sample_valid=false
        mem_total="N/A"
    fi
    
    if ! is_valid_number "$mem_used"; then
        sample_valid=false
        mem_used="N/A"
    fi
    
    if ! is_valid_number "$mem_free"; then
        sample_valid=false
        mem_free="N/A"
    fi
    
    if [ "$sample_valid" = true ]; then
        successful_samples=$((successful_samples + 1))
        cpu_usage_list+=("$cpu_usage")
        mem_total_list+=("$mem_total")
        mem_used_list+=("$mem_used")
        mem_free_list+=("$mem_free")
        
        mem_used_percent=$(calc_percent "$mem_used" "$mem_total" "N/A")
        
        printf "[第 %2d 次采集] " "$i"
        printf "CPU使用率: %6s | " "$(format_number "$cpu_usage" 1 "N/A")%"
        printf "已用内存: %6s GB (%6s) | " "$(format_number "$mem_used" 2 "N/A")" "$(format_number "$mem_used_percent" 1 "N/A")%"
        printf "可用内存: %6s GB\n" "$(format_number "$mem_free" 2 "N/A")"
    else
        failed_samples=$((failed_samples + 1))
        printf "[第 %2d 次采集] [警告] 部分数据采集失败\n" "$i"
    fi
    
    if [ "$i" -lt "$SAMPLE_COUNT" ]; then
        sleep "$INTERVAL"
    fi
done

echo "----------------------------------------------"
echo "数据采集完成，正在计算统计结果..."
echo ""
echo "[统计] 成功采集: $successful_samples 次, 失败: $failed_samples 次"

if [ "$successful_samples" -eq 0 ]; then
    echo "[错误] 所有数据采集都失败了，无法计算统计结果。"
    echo "请检查系统命令是否可用，或者系统是否提供了所需的信息。"
    exit 1
fi

echo ""

cpu_avg=$(calc_average "${cpu_usage_list[@]}")
cpu_min=$(calc_min "${cpu_usage_list[@]}")
cpu_max=$(calc_max "${cpu_usage_list[@]}")
cpu_range=$(calc_range "$cpu_min" "$cpu_max" "N/A")

mem_used_avg=$(calc_average "${mem_used_list[@]}")
mem_used_min=$(calc_min "${mem_used_list[@]}")
mem_used_max=$(calc_max "${mem_used_list[@]}")
mem_used_range=$(calc_range "$mem_used_min" "$mem_used_max" "N/A")

mem_free_avg=$(calc_average "${mem_free_list[@]}")
mem_free_min=$(calc_min "${mem_free_list[@]}")
mem_free_max=$(calc_max "${mem_free_list[@]}")
mem_free_range=$(calc_range "$mem_free_min" "$mem_free_max" "N/A")

mem_total_avg=$(calc_average "${mem_total_list[@]}")
mem_used_percent_avg=$(calc_percent "$mem_used_avg" "$mem_total_avg" "N/A")

echo "=============================================="
echo "              监控结果统计"
echo "=============================================="
echo ""
echo "【CPU 使用率】"
echo "  平均值:   $(format_number "$cpu_avg" 2 "N/A") %"
echo "  最小值:   $(format_number "$cpu_min" 2 "N/A") %"
echo "  最大值:   $(format_number "$cpu_max" 2 "N/A") %"
echo "  波动范围:  $(format_number "$cpu_range" 2 "N/A") %"
echo ""
echo "【内存使用情况】"
echo "  总内存:      $(format_number "$mem_total_avg" 2 "N/A") GB"
echo ""
echo "  已用内存:"
echo "    平均值:    $(format_number "$mem_used_avg" 2 "N/A") GB ($(format_number "$mem_used_percent_avg" 1 "N/A") %)"
echo "    最小值:    $(format_number "$mem_used_min" 2 "N/A") GB"
echo "    最大值:    $(format_number "$mem_used_max" 2 "N/A") GB"
echo "    波动范围:   $(format_number "$mem_used_range" 2 "N/A") GB"
echo ""
echo "  可用内存:"
echo "    平均值:    $(format_number "$mem_free_avg" 2 "N/A") GB"
echo "    最小值:    $(format_number "$mem_free_min" 2 "N/A") GB"
echo "    最大值:    $(format_number "$mem_free_max" 2 "N/A") GB"
echo "    波动范围:   $(format_number "$mem_free_range" 2 "N/A") GB"
echo ""
echo "=============================================="
echo "报告生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "成功样本数: $successful_samples / $SAMPLE_COUNT"
echo "=============================================="

if [ "$failed_samples" -gt 0 ]; then
    exit 2
else
    exit 0
fi
