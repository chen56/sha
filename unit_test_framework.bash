#!/usr/bin/env bash
set -o errtrace # -E trap inherited in sub script
set -o errexit # -e
set -o functrace # -T If set, any trap on DEBUG and RETURN are inherited by shell functions
set -o pipefail  # default pipeline status==last command status, If set, status=any command fail
#set -o nounset # -u: don't use it ,it is crazy, 1.bash version is diff Behavior 2.we need like this: ${arr[@]+"${arr[@]}"}




assert_fail() {
  echo "$@" >&2
}

assert_equals(){
  local expected="$1" actual="$2"  msg="$3"
  if [[ "$actual" != "$expected" ]] ; then
    local error_message;
    # shellcheck disable=SC2261
    error_message=$(cat <<ERROR_END

================================================================================
error           : $msg
--------------------<check use: echo -e, disabled Escape>-----------------------
expected: [$(echo -e "$expected")]
actual  : [$(echo -e "$actual")]
--------------------<check use: echo -E, enable Escape>-------------------------
expected: [$(echo -E "$expected")]
actual  : [$(echo -E "$actual")]
-----------------------------------<diff>---------------------------------------
$( diff -y <(echo -E "$expected") <(echo -E "$actual") || true )
================================================================================

ERROR_END
)
    echo -E "$error_message" >&2

    echo "$-:assert fail, is open vimdiff check details: (y|yes)"
    # shellcheck disable=SC2154
    # __interactive is root option
    if [[ "$__interactive" == true ]];then
      IFS= read -p "进入vimdiff看细节？打开vimdiff输入(y|Y)" -n 1 -r is_open_diff
      if [[ "$is_open_diff" == "y" || "$is_open_diff" == "Y" ]]; then
        vimdiff <(echo -E "$expected") <(echo -E "$actual")
      fi
    fi
     # TODO 应该自己打印堆栈，指出出错的test，这需要定制返回值为4xx
     return 100
  fi
}
assert_contains(){
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" != *"$expected"* ]] ; then
    assert_fail "assert fail: $msg
     actual         : [$actual]
     is not contains: [$expected]"
     return 2
  fi
}



# TODO bake.__cmd_children 命令可以改造为既可以输出全称也可以输出短名，还可以设置depth展示层级
# 查找出所有"tests."开头的函数并执行
# 这种测试有点麻烦，不如bake.test
function run_tests(){
      while IFS=$'\n' read -r functionName ; do
        [[ "$functionName" != test_* ]] && continue ;
        # run test
        printf "test: %s %-50s" "${TEST_PATH}" "$functionName()"
        # TIMEFORMAT: https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html
        # %R==real %U==user %S==sys %P==(user+sys)/real
        TIMEFORMAT="real %R user %U sys %S percent %P"
        (
          # 隔离test在子shell里，防止环境互相影响
          time "$functionName" ;
        )# 2>&1
  #    done <<< "$(compgen -A function)" # 还是declare -F 再过滤保险
      done <<<"$(declare -F | grep "declare -f" | awk {'print $3'} )"
}