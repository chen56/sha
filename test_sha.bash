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



# 所有函数名都能正确识别，不漏一个，原先代码多了个空格，导致最后一个函数名包含一个空格：
#   "$(declare -F | grep "declare -f" | cut -d " " -f 3)"
test_all_funcname_is_ok() {
 script='
     . ./sha.bash

    a() { echo "a"; } 
    b() { echo "b"; } 
    sha "$@"
  '
  
  assert_equals "a" "$(bash -c "$script" _ "a" 2>&1)"
  assert_equals "b" "$(bash -c "$script" _ "b" 2>&1)"
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

  assert_equals "a" "$(bash -c "$script" _ "a" 2>&1)"
  assert_equals "b/b1" "$(bash -c "$script" _ "b" "b1" 2>&1)"
  assert_equals "b/b2" "$(bash -c "$script" _ "b" "b2" 2>&1)"
}

run_tests
