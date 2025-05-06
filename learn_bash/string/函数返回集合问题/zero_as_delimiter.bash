#!/usr/bin/env bash

# Function that outputs items encoded with printf %q, separated by \0
my_q_encoded_function() {
    local item1="one
item"
    local item2="two item with space"
    local item3="three's item with\backslash and \"quotes\""
    local item4=$'four\0item with null byte' # 演示包含 \0 的情况

    # "\0" as the delimiter
    printf "%s\0" "$item1"; 
    printf "%s\0" "$item2"; 
    printf "%s\0" "$item3";  
    printf "%s\0" "$item4";  
    # ... 输出更多项目 ...
}

echo "--- use while + read ---"

while IFS= read -r -d '' q_encoded_item; do
    echo "[$q_encoded_item]"

done < <(my_q_encoded_function) # 使用进程替换将函数输出喂给 while 循环

echo "--- use mapfile ---"

mapfile -d '' my_encoded_items_array < <(my_q_encoded_function)

for q_encoded_item in "${my_encoded_items_array[@]}"; do
    echo "[$q_encoded_item]"
done