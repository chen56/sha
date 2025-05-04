#!/usr/bin/env bash

# good
function use_echo() {
    echo "a"
}
function use_printf() {
    printf "%s" "a"
}

echo "use echo"
use_echo | od -c -t x1

echo "use printf"
use_printf | od -c -t x1

# 用echo返回的字符串结果会多一个换行符，如果被自动删除换行符的方式使用，比如$(use_echo) 是没问题的，但如果其他形式使用，刚好又把换行符作为内容，可能会出问题。