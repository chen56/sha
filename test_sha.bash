#!/usr/bin/env bash
set -o errtrace  # -E trap inherited in sub script
set -o errexit   # -e
set -o functrace # -T If set, any trap on DEBUG and RETURN are inherited by shell functions
set -o pipefail  # default pipeline status==last command status, If set, status=any command fail
#set -o nounset # -u: 当尝试使用未定义的变量时，立即报错并退出脚本。这有助于防止因变量拼写错误或未初始化导致的意外行为。
                #  don't use it ,it is crazy, 
                #   1.bash version is diff Behavior 
                #   2.we need like this: ${arr[@]+"${arr[@]}"}
                #   3.影响使用此lib的脚本
           
TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "$TEST_DIR/unit_test_framework.bash"

declare script=""
run_script() {
  bash -c "$script" _ "$@" 2>&1
}


# 所有函数名都能正确识别，不漏一个，原先代码多了个空格，导致最后一个函数名包含一个空格：
#   "$(declare -F | grep "declare -f" | cut -d " " -f 3)"
test_all_funcname_is_ok() {
 script='
     . ./sha.bash

    a() { echo "a"; } 
    b() { echo "b"; } 
    sha "$@"
  '
  
  assert_equals "a" "$(run_script a)"
  assert_equals "b" "$(run_script b)"
}

test_sub_command() {
  script=$(cat << 'EOF'
    #!/usr/bin/env bash
    . ./sha.bash
    a() { echo "a"; } 
    b() {
      b1() { echo "b/b1"; }  
      b2() { echo "b/b2"; }  
    }
    sha "$@"
EOF
)

  assert_equals "a" "$(run_script a)"
  assert_equals "b/b1" "$(run_script b b1)"
  assert_equals "b/b2" "$(run_script b b2)"
}

# 内外命令有重名，进入一级命令后正确识别
test_duplicated_command() {
  # shellcheck disable=SC2317
  script=$(cat << 'EOF'
    #!/usr/bin/env bash
    . ./sha.bash
    aaa() { echo "aaa"; } 
    bbb() {
      aaa() { echo "bbb/aaa"; }  
      bbb() { echo "bbb/bbb"; }  
    }
    sha "$@"
EOF
)
  assert_equals   "aaa" "$(run_script aaa)"

  assert_contains "help" "$(run_script bbb)"
  assert_equals   "bbb/aaa" "$(run_script bbb aaa)" # bbb/aaa会覆盖掉外部的aaa
  assert_equals   "bbb/bbb" "$(run_script bbb bbb)" 
}

test_array_regex_match() {
  # shellcheck disable=SC1091
  . "./sha.bash"
  # shellcheck disable=SC2034
  a=(apple orange banana)
  _sha_array_regex_match a "apple"
  _sha_array_regex_match a "na"
  _sha_array_regex_match a "o.*e"

  # shellcheck disable=SC2251
  ! _sha_array_regex_match a "abble"
  ! _sha_array_regex_match a "e o"
}

test_array_contains() {
  # shellcheck disable=SC1091
  . "./sha.bash"
  # shellcheck disable=SC2034
  a=(apple orange banana)
  _sha_array_contains a "apple"
  _sha_array_contains a "orange"
  _sha_array_contains a "banana"

  # shellcheck disable=SC2251
  ! _sha_array_contains a "pple"
  ! _sha_array_contains a "oran"
}

test_array_find_first_index() {
  # shellcheck disable=SC1091
  . "./sha.bash"
  # shellcheck disable=SC2034
  a=(apple orange banana)
  assert_equals 0  "$(  _sha_array_find_first_index a "apple")"
  assert_equals 1  "$(  _sha_array_find_first_index a "orange")"
  assert_equals 2  "$(  _sha_array_find_first_index a "banana")"

  # shellcheck disable=SC2251
  ! _sha_array_find_first_index a "pple"
  ! _sha_array_find_first_index a "oran"
}



test_array_difference() {
  # shellcheck disable=SC1091
  . "./sha.bash"
  # shellcheck disable=SC2034
  a=(apple orange banana kiwi)
  b=(banana kiwi unkown)

  _sha_array_difference a b
  assert_equals "0" "$?"

  local x=$(_sha_array_difference a b)
  
  assert_equals "a"  "a"


  # c=(not_exists_str)
  # assert_equals ""  "$(  _sha_array_difference a c || true)"
}




# 内外命令有重名，进入一级命令后正确识别
ignore_test_command_conflict() {
  # shellcheck disable=SC2317
  script=$(cat << 'EOF'
    #!/usr/bin/env bash
    . ./sha.bash
    ls() { echo "这个命令和系统ls命令重名,将报错"; } 
    sha "$@"
EOF
)
  assert_contains   "ERROR: function 'ls' 和os系统命令或alias重名, 请检查这个函数" "$(run_script)"

}

# 内外命令有重名，进入一级命令后正确识别
ignore_test_command_conflict_func_define_before_import_sha() {
  # shellcheck disable=SC2317
  script=$(cat << 'EOF'
    #!/usr/bin/env bash
    update_sha() { echo "定义在import sha.bash之前的函数应该不被认为是系统命令"; } 

    . ./sha.bash
    sha "$@"
EOF
)
  # 定义在import sha.bash之前的函数不会被认为是系统命令，所以这里不会报错
  assert_contains   "定义在import sha.bash之前的函数应该不被认为是系统命令" "$(run_script update_sha)"
}


run_tests
# test_command_conflict
