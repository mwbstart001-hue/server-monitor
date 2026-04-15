#!/bin/bash

SERVER_NAME=$(hostname)
SAMPLE_COUNT=5
INTERVAL=1

echo "=============================================="
echo "      服务器资源监控信息采集脚本"
echo "=============================================="
echo "服务器名称: $SERVER_NAME"
echo "采集时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "采集次数: $SAMPLE_COUNT 次"
echo "采集间隔: $INTERVAL 秒"
echo "=============================================="
echo ""

cpu_usage_list=()
mem_total_list=()
mem_used_list=()
mem_free_list=()

get_system_info() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        cpu_usage=$(top -l 2 -n 0 2>/dev/null | grep 'CPU usage' | tail -n 1 | awk '{printf "%.1f", $3 + $5}')
        
        mem_total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
        mem_total_gb=$(echo "scale=2; $mem_total_bytes / 1024 / 1024 / 1024" | bc 2>/dev/null)
        
        vm_stat_output=$(vm_stat 2>/dev/null)
        page_size=$(sysctl -n hw.pagesize 2>/dev/null)
        
        free_pages=$(echo "$vm_stat_output" | grep 'Pages free' | awk '{print $3}' | tr -d '.')
        active_pages=$(echo "$vm_stat_output" | grep 'Pages active' | awk '{print $3}' | tr -d '.')
        inactive_pages=$(echo "$vm_stat_output" | grep 'Pages inactive' | awk '{print $3}' | tr -d '.')
        speculative_pages=$(echo "$vm_stat_output" | grep 'Pages speculative' | awk '{print $3}' | tr -d '.')
        wired_pages=$(echo "$vm_stat_output" | grep 'Pages wired down' | awk '{print $4}' | tr -d '.')
        compressed_pages=$(echo "$vm_stat_output" | grep 'Pages occupied by compressor' | awk '{print $5}' | tr -d '.')
        
        free_bytes=$((free_pages * page_size))
        used_bytes=$(((active_pages + inactive_pages + speculative_pages + wired_pages + compressed_pages) * page_size))
        
        mem_free_gb=$(echo "scale=2; $free_bytes / 1024 / 1024 / 1024" | bc 2>/dev/null)
        mem_used_gb=$(echo "scale=2; $used_bytes / 1024 / 1024 / 1024" | bc 2>/dev/null)
    else
        cpu_usage=$(top -bn2 -d0.1 2>/dev/null | grep 'Cpu(s)' | tail -n 1 | awk -F'[ ,]+' '{printf "%.1f", $2 + $4}')
        
        mem_info=$(free -m 2>/dev/null | grep 'Mem')
        mem_total_mb=$(echo "$mem_info" | awk '{print $2}')
        mem_used_mb=$(echo "$mem_info" | awk '{print $3}')
        mem_free_mb=$(echo "$mem_info" | awk '{print $4 + $6 + $7}')
        
        mem_total_gb=$(echo "scale=2; $mem_total_mb / 1024" | bc 2>/dev/null)
        mem_used_gb=$(echo "scale=2; $mem_used_mb / 1024" | bc 2>/dev/null)
        mem_free_gb=$(echo "scale=2; $mem_free_mb / 1024" | bc 2>/dev/null)
    fi
    
    echo "$cpu_usage|$mem_total_gb|$mem_used_gb|$mem_free_gb"
}

calc_average() {
    local sum=0
    local count=0
    for value in "$@"; do
        sum=$(echo "scale=4; $sum + $value" | bc 2>/dev/null)
        ((count++))
    done
    if [ "$count" -gt 0 ]; then
        echo "scale=2; $sum / $count" | bc 2>/dev/null
    else
        echo "0.00"
    fi
}

calc_min() {
    local min="$1"
    shift
    for value in "$@"; do
        if (( $(echo "$value < $min" | bc -l 2>/dev/null) )); then
            min="$value"
        fi
    done
    echo "$min"
}

calc_max() {
    local max="$1"
    shift
    for value in "$@"; do
        if (( $(echo "$value > $max" | bc -l 2>/dev/null) )); then
            max="$value"
        fi
    done
    echo "$max"
}

calc_range() {
    local min="$1"
    local max="$2"
    echo "scale=2; $max - $min" | bc 2>/dev/null
}

echo "开始采集数据..."
echo "----------------------------------------------"

for ((i=1; i<=SAMPLE_COUNT; i++)); do
    info=$(get_system_info)
    cpu_usage=$(echo "$info" | cut -d'|' -f1)
    mem_total=$(echo "$info" | cut -d'|' -f2)
    mem_used=$(echo "$info" | cut -d'|' -f3)
    mem_free=$(echo "$info" | cut -d'|' -f4)
    
    cpu_usage_list+=("$cpu_usage")
    mem_total_list+=("$mem_total")
    mem_used_list+=("$mem_used")
    mem_free_list+=("$mem_free")
    
    mem_used_percent=$(echo "scale=2; ($mem_used / $mem_total) * 100" | bc 2>/dev/null)
    
    printf "[第 %2d 次采集] " "$i"
    printf "CPU使用率: %5.1f%% | " "$cpu_usage"
    printf "已用内存: %5.2f GB (%5.1f%%) | " "$mem_used" "$mem_used_percent"
    printf "可用内存: %5.2f GB\n" "$mem_free"
    
    if [ "$i" -lt "$SAMPLE_COUNT" ]; then
        sleep "$INTERVAL"
    fi
done

echo "----------------------------------------------"
echo "数据采集完成，正在计算统计结果..."
echo ""

cpu_avg=$(calc_average "${cpu_usage_list[@]}")
cpu_min=$(calc_min "${cpu_usage_list[@]}")
cpu_max=$(calc_max "${cpu_usage_list[@]}")
cpu_range=$(calc_range "$cpu_min" "$cpu_max")

mem_used_avg=$(calc_average "${mem_used_list[@]}")
mem_used_min=$(calc_min "${mem_used_list[@]}")
mem_used_max=$(calc_max "${mem_used_list[@]}")
mem_used_range=$(calc_range "$mem_used_min" "$mem_used_max")

mem_free_avg=$(calc_average "${mem_free_list[@]}")
mem_free_min=$(calc_min "${mem_free_list[@]}")
mem_free_max=$(calc_max "${mem_free_list[@]}")
mem_free_range=$(calc_range "$mem_free_min" "$mem_free_max")

mem_total_avg=$(calc_average "${mem_total_list[@]}")
mem_used_percent_avg=$(echo "scale=2; ($mem_used_avg / $mem_total_avg) * 100" | bc 2>/dev/null)

echo "=============================================="
echo "              监控结果统计"
echo "=============================================="
echo ""
echo "【CPU 使用率】"
echo "  平均值:  $cpu_avg %"
echo "  最小值:  $cpu_min %"
echo "  最大值:  $cpu_max %"
echo "  波动范围: $cpu_range %"
echo ""
echo "【内存使用情况】"
echo "  总内存:     $mem_total_avg GB"
echo ""
echo "  已用内存:"
echo "    平均值:   $mem_used_avg GB ($mem_used_percent_avg %)"
echo "    最小值:   $mem_used_min GB"
echo "    最大值:   $mem_used_max GB"
echo "    波动范围:  $mem_used_range GB"
echo ""
echo "  可用内存:"
echo "    平均值:   $mem_free_avg GB"
echo "    最小值:   $mem_free_min GB"
echo "    最大值:   $mem_free_max GB"
echo "    波动范围:  $mem_free_range GB"
echo ""
echo "=============================================="
echo "报告生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="
