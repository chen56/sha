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
source "$TEST_DIR/sake.bash"
# shellcheck disable=SC1091
source "$TEST_DIR/unit_test_framework.bash"


test_hello(){
  local script='
    set -o errexit   # -e
    echo "hello world"
  '
  
  assert_equals "hello world" "$(bash -c "$script" 2>&1)"
}

test_2(){
  local script='
set -e
. ./sake.bash
@cmd "build <src_dir>"run build""
'
  
  assert_equals "hello world" "$(eval "$script" 2>&1)"
}


run_tests
