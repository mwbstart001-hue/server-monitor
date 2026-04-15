#!/bin/bash

echo "=============================================="
echo "   服务器监控脚本 - 工具函数测试"
echo "=============================================="
echo ""

test_passed=0
test_failed=0

test_result() {
    local test_name="$1"
    local result="$2"
    local expected="$3"
    
    if [ "$result" = "$expected" ]; then
        echo "✅ PASS: $test_name"
        ((test_passed++))
    else
        echo "❌ FAIL: $test_name"
        echo "   期望: [$expected]"
        echo "   实际: [$result]"
        ((test_failed++))
    fi
}

test_exit_code() {
    local test_name="$1"
    local actual_exit="$2"
    local expected_exit="$3"
    
    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "✅ PASS: $test_name"
        ((test_passed++))
    else
        echo "❌ FAIL: $test_name"
        echo "   期望退出码: $expected_exit"
        echo "   实际退出码: $actual_exit"
        ((test_failed++))
    fi
}

echo "--- 测试 1: 直接用 awk 进行数值验证 ---"
echo ""

is_valid_number_awk() {
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

echo "测试有效数值:"
is_valid_number_awk "0"; test_exit_code "is_valid(0)" $? 0
is_valid_number_awk "123"; test_exit_code "is_valid(123)" $? 0
is_valid_number_awk "-123"; test_exit_code "is_valid(-123)" $? 0
is_valid_number_awk "123.45"; test_exit_code "is_valid(123.45)" $? 0
is_valid_number_awk "-123.45"; test_exit_code "is_valid(-123.45)" $? 0

echo ""
echo "测试无效数值:"
is_valid_number_awk ""; test_exit_code "is_valid('')" $? 1
is_valid_number_awk "abc"; test_exit_code "is_valid(abc)" $? 1
is_valid_number_awk "12a3"; test_exit_code "is_valid(12a3)" $? 1

echo ""
echo "--- 测试 2: awk 数值比较 ---"
echo ""

compare_awk() {
    local a="$1"
    local op="$2"
    local b="$3"
    local result=$(echo | awk -v a="$a" -v b="$b" -v op="$op" '{
        if (op == "gt") print (a > b) ? "true" : "false"
        else if (op == "lt") print (a < b) ? "true" : "false"
        else if (op == "eq") print (a == b) ? "true" : "false"
    }')
    echo "$result"
}

result=$(compare_awk "1" "lt" "2")
test_result "1 < 2" "$result" "true"

result=$(compare_awk "2" "lt" "1")
test_result "2 < 1" "$result" "false"

result=$(compare_awk "2" "gt" "1")
test_result "2 > 1" "$result" "true"

result=$(compare_awk "1.5" "lt" "2.5")
test_result "1.5 < 2.5" "$result" "true"

result=$(compare_awk "3.5" "gt" "2.5")
test_result "3.5 > 2.5" "$result" "true"

echo ""
echo "--- 测试 3: awk 数值计算 ---"
echo ""

echo "测试除法:"
result=$(echo "10 2" | awk '{printf "%.2f", $1 / $2}')
test_result "10 / 2" "$result" "5.00"

result=$(echo "10 3" | awk '{printf "%.2f", $1 / $2}')
test_result "10 / 3" "$result" "3.33"

result=$(echo "-10 5" | awk '{printf "%.2f", $1 / $2}')
test_result "-10 / 5" "$result" "-2.00"

echo ""
echo "测试加法:"
result=$(echo "10 20 30" | awk '{printf "%.2f", $1 + $2 + $3}')
test_result "10 + 20 + 30" "$result" "60.00"

result=$(echo "1.5 2.5" | awk '{printf "%.2f", $1 + $2}')
test_result "1.5 + 2.5" "$result" "4.00"

echo ""
echo "测试减法:"
result=$(echo "30 5" | awk '{printf "%.2f", $1 - $2}')
test_result "30 - 5" "$result" "25.00"

result=$(echo "7.7 3.3" | awk '{printf "%.2f", $1 - $2}')
test_result "7.7 - 3.3" "$result" "4.40"

echo ""
echo "--- 测试 4: awk 百分比计算 ---"
echo ""

result=$(echo "50 100" | awk '{printf "%.1f", ($1 / $2) * 100}')
test_result "(50/100)*100" "$result" "50.0"

result=$(echo "25 100" | awk '{printf "%.1f", ($1 / $2) * 100}')
test_result "(25/100)*100" "$result" "25.0"

result=$(echo "1 3" | awk '{printf "%.1f", ($1 / $2) * 100}')
test_result "(1/3)*100" "$result" "33.3"

echo ""
echo "--- 测试 5: awk 平均值计算 ---"
echo ""

result=$(echo "10 20 30" | awk '{printf "%.2f", ($1 + $2 + $3) / 3}')
test_result "avg(10,20,30)" "$result" "20.00"

result=$(echo "1 2 3 4 5 6 7 8 9 10" | awk '{
    sum = 0; 
    for(i=1; i<=NF; i++) sum += $i; 
    printf "%.2f", sum / NF
}')
test_result "avg(1..10)" "$result" "5.50"

echo ""
echo "--- 测试 6: awk min/max ---"
echo ""

result=$(echo "10 20 5 30" | awk '{
    min = $1; max = $1;
    for(i=2; i<=NF; i++) {
        if ($i < min) min = $i;
        if ($i > max) max = $i;
    }
    print min "|" max
}')
min_val=$(echo "$result" | cut -d'|' -f1)
max_val=$(echo "$result" | cut -d'|' -f2)
test_result "min(10,20,5,30)" "$min_val" "5"
test_result "max(10,20,5,30)" "$max_val" "30"

result=$(echo "5.5 3.3 7.7" | awk '{
    min = $1; max = $1;
    for(i=2; i<=NF; i++) {
        if ($i < min) min = $i;
        if ($i > max) max = $i;
    }
    print min "|" max
}')
min_val=$(echo "$result" | cut -d'|' -f1)
max_val=$(echo "$result" | cut -d'|' -f2)
test_result "min(5.5,3.3,7.7)" "$min_val" "3.3"
test_result "max(5.5,3.3,7.7)" "$max_val" "7.7"

echo ""
echo "--- 测试 7: awk bytes to GB ---"
echo ""

gb=$(echo "1024 * 1024 * 1024" | bc)
result=$(echo "$gb" | awk '{printf "%.2f", $1 / 1024 / 1024 / 1024}')
test_result "1GB in bytes to GB" "$result" "1.00"

gb=$(echo "2 * 1024 * 1024 * 1024" | bc)
result=$(echo "$gb" | awk '{printf "%.2f", $1 / 1024 / 1024 / 1024}')
test_result "2GB in bytes to GB" "$result" "2.00"

echo ""
echo "--- 测试 8: awk 格式输出 ---"
echo ""

result=$(echo "123.456" | awk '{printf "%.2f", $1}')
test_result "format(123.456, 2)" "$result" "123.46"

result=$(echo "123.4" | awk '{printf "%.2f", $1}')
test_result "format(123.4, 2)" "$result" "123.40"

result=$(echo "123" | awk '{printf "%.2f", $1}')
test_result "format(123, 2)" "$result" "123.00"

echo ""
echo "--- 测试 9: awk 大于0判断 ---"
echo ""

is_greater_zero() {
    local val="$1"
    local result=$(echo | awk -v v="$val" '{if (v > 0) print "yes"; else print "no"}')
    echo "$result"
}

result=$(is_greater_zero "1")
test_result "1 > 0" "$result" "yes"

result=$(is_greater_zero "0.5")
test_result "0.5 > 0" "$result" "yes"

result=$(is_greater_zero "0")
test_result "0 > 0" "$result" "no"

result=$(is_greater_zero "-1")
test_result "-1 > 0" "$result" "no"

result=$(is_greater_zero "-0.5")
test_result "-0.5 > 0" "$result" "no"

echo ""
echo "--- 测试 10: check_command 函数 ---"
echo ""

check_cmd() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_cmd "awk"; test_exit_code "check_cmd(awk)" $? 0
check_cmd "grep"; test_exit_code "check_cmd(grep)" $? 0
check_cmd "nonexistent_command_xyz"; test_exit_code "check_cmd(nonexistent)" $? 1

echo ""
echo "=============================================="
echo "              测试结果汇总"
echo "=============================================="
echo ""
echo "✅ 通过: $test_passed"
echo "❌ 失败: $test_failed"
echo ""

if [ "$test_failed" -eq 0 ]; then
    echo "🎉 所有工具函数测试通过！"
    exit 0
else
    echo "⚠️  有 $test_failed 个测试失败"
    exit 1
fi
