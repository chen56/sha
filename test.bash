#!/usr/bin/env bash
set -o errtrace # -E trap inherited in sub script
set -o errexit # -e
set -o functrace # -T If set, any trap on DEBUG and RETURN are inherited by shell functions
set -o pipefail  # default pipeline status==last command status, If set, status=any command fail
#set -o nounset # -u: don't use it ,it is crazy, 1.bash version is diff Behavior 2.we need like this: ${arr[@]+"${arr[@]}"}

########################################################
# 本测试命令和使用普通bake 应用脚本的模式一模一样
# 运行测试:   ./tests.bash test
# 列出子命令: ./tests.bash -h
########################################################


function _real_path() (
  cd -P "$(dirname -- "$1")"
  file="$PWD/$(basename -- "$1")"
  while [[ -L "$file" ]]; do
    cd -P "$(dirname -- "$file")"
    file="$(readlink -- "$file")"
    cd -P "$(dirname -- "$file")"
    file="$PWD/$(basename -- "$file")"
  done
  echo "$file"
)

TEST_PATH="$(_real_path "${BASH_SOURCE[0]}")"
TEST_DIR="$(dirname "$TEST_PATH")"
TEST_FILE="$(basename "$TEST_PATH")"

source "$TEST_DIR/bake.bash"


_________________________test_framework_start(){ echo x;}

assert_fail() {
  echo "$@" >&2
}

@is_escape(){
  local actual="$1" expected="$2" msg="$3"
  local escaped; escaped="$(printf '%q' "${actual}")"
  escaped="${escaped#$\'}" # "$'str'" remove begin "$'" => "str'"
  escaped="${escaped%\'*}" # "str'" remove end "'"  => "str"
  if [[ "$escaped" != "$expected" ]] ; then
    assert_fail "assert is_escape fail: $msg
     actual       : [$escaped]
     is not escape: [$expected]"
     echo "diff------------------------->" >&2
     diff <(echo -e "$expected") <(echo -e "$actual") >&2
     return 2
  fi
}

# escape to 'xxx' or $'xxx'
#  https://www.gnu.org/software/bash/manual/bash.html#ANSI_002dC-Quoting
bake.str.escape() {
  #  from 2016 bash 4.4
  #  ${parameter@Q} : quoted in a format that can be reused as input
  # to 'xxx' or $'xxx'
  printf '%s\n' "${1@Q}"
}
# unescape from 'xxx' or $'xxx'
bake.str.unescape() {
  local str=${1}
  # $'xx' => xx
  if [[ "$str" == "\$'"*"'" ]]; then
    str="${str:2:-1}"
  # 'xx' => xx
  elif [[ "${str}" == "'"*"'" ]]; then
    str="${str:1:-1}"
  fi
  #  from 2016 bash 4.4
  #  ${parameter@E} expanded as with the $'...' quoting mechansim
  printf '%s' "${str@E}"
}


@is(){
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" != "$expected" ]] ; then
    assert_fail "assert is fail: $msg
     actual         : [$actual]
     is not         : [$expected]
     --------------------------------------------------
     actual escape  : [$(printf '%q' "$actual")]
     is not escape  : [$(printf '%q' "$expected")]
     "
     echo "diff------------------------->" >&2
     diff <(echo -e "$expected") <(echo -e "$actual") >&2
     return 2
  fi
}
@contains(){
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" != *"$expected"* ]] ; then
    assert_fail "assert fail: $msg
     actual         : [$actual]
     is not contains: [$expected]"
     return 2
  fi
}


# Usage: assert <actual> <assert_op_func> <expected> [msg]
# Sample: assert $(( 1+1 )) @is "2"
assert(){
  local actual="$1" op="$2" expected="$3" msg="$4"
  "$op" "$actual" "$expected" "$msg"
}

______________________________study_start(){ echo x;}

# above is test framework
# $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# below is test case

#######################################################
## study bash or some other
#######################################################
# IFS : https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_05
study.string.escape(){
  # $'' 语法
  assert $'1\n2' @is '1
2'
  assert '1\n2' @is '1\n2'

  assert $'1
2' @is $'1\n2'

  x="1
2"
  assert "$(printf '%q' "$x" )" @is "$'1\n2'"
}

study.read(){
  local expected="";
  echo -e "1\n2" | while read -r x ; do
    expected+="$1,"
  done
  assert "$expected" @is '1,2,'
}
study.function.return(){
  (
    s(){
      printf "%s" "a b
c d";
    }
    str="$(s)"
    assert "${str}" @is $'a b\nc d'
    printf "${str}" | od -c -td1
    read -a arr <<< "${str}"
        assert "${#arr[@]}" @is 2
  )

  (
    # 需重新构造更清洗的用例
    q(){
      printf "%q" "a b
c d";
    }
    str="$(q)"
    assert "${str}" @is "$'a b\nc d'"
    printf "${str}" | od -c -td1
    read -a arr <<< "${str}"
    # read 按IFS默认$' \n\t'，即用<space>, <newline>,<tab>分词
    # 由于printf "%q"会对非打印字符进行转义，<newline>已经被转为\和n，所以read分词时，
    # 并没有任何<newline>
    assert "${#arr[@]}" @is 3
    assert "$(printf '[%s]' "${arr[@]}" )" @is "[$'a][bnc][d']"

    IFS=$'\n' read -a arr <<< "${str}"
    # 我们重设分词符号只有$'\n', 但其实<newline>已被转义，所以并没有任何<newline>
    assert "${#arr[@]}" @is 1
    assert "$(printf '[%s]' "${arr[@]}" )" @is "[$'a bnc d']"

    # 函数的开发者有职责自己先区分好，我这个函数的输出，什么算是1行，算是1行的，就用printf "%q"转义
    # 那么，函数的调用者就有机会决定怎么分词
    # 函数的调用者有职责，对函数返回的字符串，自己先区分好，我拿到的函数输出，要不要分行处理
    # 就用IFS=$'\n' read -a arr <<< "${str}"分词
  )
}
# Usage: pipe <callback> [args...]
# callback: callback <line>
# Sample: cat file | pipe echo
study.pipe(){
  local func="$1" ; shift;
  for arg in "$@"; do
  $func "$arg"
  done
  if ! [[ -t 0 ]]; then
    while  read line; do
      $func "$line"
    done
  fi
}

____________________________test_start(){ echo x;}


tests.api_cmd_parse(){
  bake.opt --cmd "tests.cmd.parse" --name stringOpt --type string
  bake.opt --cmd "tests.cmd.parse" --name boolOpt --type bool
  bake.opt --cmd "tests.cmd.parse" --name listOpt --type list

  assert "$(bake.parse "tests.cmd.parse" --boolOpt )" @is 'declare boolOpt="true";
declare optShift=1;'
  assert "$(bake.parse "tests.cmd.parse" --stringOpt "1 2" )" @is 'declare stringOpt="1 2";
declare optShift=2;'

  # list type option
  assert "$(bake.parse "tests.cmd.parse" --listOpt "a 1" --listOpt "b 2" )" @is 'declare listOpt=([0]="a 1" [1]="b 2");
declare optShift=4;'

  # no exists cmd
  assert "$(bake.parse "no.exists.func" --unknow_opt bool)" @is "declare optShift=0;"

  # no exists option
  assert "$(bake.parse "tests.cmd.parse" --no_exists_opt)" @is "declare optShift=0;"
}

tests.api_opt(){
  bake.opt --cmd "tests.opt.add" --name boolopt --type bool
}

tests.api_opt_value_parse_and_get_value(){
  bake.opt --cmd "tests.opt.add" --name xxx --type string
  echo $(bake.parse "tests.opt.add" --xxx chen)
  eval "$(bake.parse "tests.opt.add" --xxx chen)"
  assert "$xxx" @is "chen"
}


function tests.str_escape() {
    assert "$(bake.str.escape $'1' )"     @is "'1'"
    assert "$(bake.str.escape $'1 ')"     @is "'1 '"
    assert "$(bake.str.escape $'1 2 "')"  @is "'1 2 \"'"
    assert "$(bake.str.escape $'1 "')"    @is "'1 \"'"
    assert "$(bake.str.escape $'1 2\n')"  @is "\$'1 2\n'"
}
function tests.str_unescape() {
    assert "$(bake.str.unescape "$(bake.str.escape $'1'    )")"      @is $'1'
    assert "$(bake.str.unescape "$(bake.str.escape $'1 2'  )")"      @is $'1 2'
    assert "$(bake.str.unescape "$(bake.str.escape $'1 " ' )")"      @is $'1 " '
    assert "$(bake.str.unescape "$(bake.str.escape $'1 \n ' )")"     @is $'1 \n '
}
study.declare(){
  (
    declare a=1 b=2
    assert "$a" @is "1"
    assert "$b" @is "2"
  )

  (
    s='a=1 b=2'
    declare $(printf "%s" "$s")
    assert "$a" @is "1"
    assert "$b" @is "2"
  )
  (
    s='a=1 b=2'
    declare $(printf "%s" "$s")
    assert "$a" @is "1"
    assert "$b" @is "2"
  )

    # declare ansi c quoting $''
  (
    err=$( declare $(printf "%s" "a=$'1 2'") 2>&1  ) || true
    assert "$err" @contains "2'': not a valid identifier"
  )

  (

    IFS=$'\n'
    declare $(printf "%s" "a=$'1 2'
b=$'3 4'")
    assert "$a" @is "$'1 2'"
    assert "$b" @is "$'3 4'"
  )

  (
    # 目前看declare的脚本注射是比较安全的
    # "|| true" 防止set -o errexit
    err=$( declare $(printf "%s" 'a=1 b=2 ls -al -- ll') 2>&1  ) || true
    assert "$err" @contains "-al': not a valid identifier"
    err=$( declare $(printf "%s" 'a=$(ls -al)') 2>&1  ) || true
    assert "$err" @contains "-al)': not a valid identifier"
    err=$( declare $(printf "%s" 'a=b $(ls)=x') 2>&1  ) || true
    assert "$err" @contains $"ls)=x': not a valid identifier"
    err=$( declare $(printf "%s" 'a=b `ls`=x') 2>&1  ) || true
    assert "$err" @contains "=x': not a valid identifier"
  )

}
# eval 用起来比declare 省心多了
study.eval(){
  (
    eval "a=$'1 2' b=$'3 4'"
    assert "$a" @is "1 2"
    assert "$b" @is "3 4"
  )

  {
  # 包含换行符也没问题
    eval "a=$'1 2'
          b=$'3 4'"
    assert "$a" @is "1 2"
    assert "$b" @is "3 4"
  }

  (
  # 数组也没问题
    eval "a=($'1 2'
    $'3\n4')"
    assert "${#a[@]}" @is 2
    assert "${a[0]}" @is "1 2"
    assert "${a[1]}" @is $'3\n4'
  )

  {
  # 关联数组也没问题
    eval "declare -A a=([a]=$'1\n2' [b]=$'2' )"
    assert "${#a[@]}" @is 2
    assert "${a[a]}" @is $'1\n2'
    assert "${a[b]}" @is $'2'
  }
  (
    # 用$'' ANSI C Quoting格式看来也是安全的
    eval "a=$'1 2' b=$'3 4 script inject not work'"
    assert "$a" @is "1 2"
    assert "$b" @is "3 4 script inject not work"
  )
}

study.array(){
  a=("line1 a
line2" x)
    assert "$(printf "[%s]" ${a[@]})" @is $'[line1][a][line2][x]'
    assert "$(printf "[%s]" ${a[@]})" @is $'[line1][a][line2][x]'
    # 由于"$@" 特殊语法，数组可已包含空格换行符， 不影响分词
    assert "$(printf "[%s]" "${a[@]}")" @is $'[line1 a\nline2][x]'

}

#######################################################
## bake test case
#######################################################

tests.assert_sample(){
  assert $((1+1)) @is 2
}

tests.path_dirname(){
  assert "$(bake._path_dirname a/b/c '/')" @is "a/b"
  assert "$(bake._path_dirname a     '/')" @is ""
  assert "$(bake._path_dirname ""    '/')" @is ""

  # abstract path
  assert "$(bake._path_dirname /a/b/c '/')" @is "/a/b"
  assert "$(bake._path_dirname /a     '/')" @is ""
  assert "$(bake._path_dirname /      '/')" @is ""
}
tests.path_first(){
  assert "$(bake._path_first a/b/c  '/')" @is "a"
  assert "$(bake._path_first a      '/')" @is "a"
  assert "$(bake._path_first ''     '/')" @is ""

  assert "$(bake._path_first /a/b/c '/')" @is "/a"
}

tests.path_basename(){
  assert "$(bake._path_basename a/b/c '/')" @is "c"
  assert "$(bake._path_basename a     '/')" @is "a"
  assert "$(bake._path_basename ""    '/')" @is ""

  # abstract path
  assert "$(bake._path_basename "/a"  '/')" @is "a"
  assert "$(bake._path_basename "/"  '/')"  @is ""
}

tests.str_cutLeft(){
  assert "$(bake._str_cutLeft a/b/c 'a/b/')" @is "c"
  assert "$(bake._str_cutLeft a/b/c '')" @is "a/b/c"

  assert "$(bake._str_cutLeft /a/b/c '/')" @is "a/b/c"

  assert "$(bake._str_cutLeft a/b/c 'notStart')" @is "a/b/c"
  assert "$(bake._str_cutLeft a/b/c '/')"        @is "a/b/c"
}


tests.cmd_up_chain(){
  assert "$(bake._cmd_up_chain a.b)" @is_escape "a.b\na\nroot"
  assert "$(bake._cmd_up_chain 'root')" @is "root"
  assert "$(bake._cmd_up_chain '')" @is "root"
}

# @fixme 这里有问题，判断错了
tests.cmd_children(){
  assert "$(bake._cmd_children test)" @is_escape "tests"
}

tests.str_split(){
  assert "$(bake._str_split "a/b" '/')"  @is_escape "a\nb"
  assert "$(bake._str_split "a/b/" '/')" @is_escape "a\nb"

  # abstract path
  assert "$(bake._str_split "/a/b" '/')"  @is_escape "\na\nb"
  assert "$(bake._str_split "/a/b/" '/')" @is_escape "\na\nb"


  # 包含破坏性特殊字符
  assert "$(bake._str_split $'a\nb'  "/" )"  @is_escape "a\nb"
  assert "$(bake._str_split $'a\n/b' "/" )"  @is_escape "a\n\nb"
  assert "$(bake._str_split "a
/b
" )"  @is_escape "a\n\nb"

  # default delimiter
  assert "$(bake._str_split "a/b"  )"  @is_escape "a\nb"

  # other delimiter
  assert "$(bake._str_split "a.b" '.')"  @is_escape "a\nb"
}

tests.cmd_register(){
  bake._cmd_register
  assert "$(bake.info | grep tests.cmd_register)" \
    @contains "tests.cmd_register"
}

tests.data_children(){
  assert "$(bake._data_children "bake.opt/opts")" @is_escape "abbr\ncmd\ndefault\ndesc\nname\nrequired\ntype"
}

tests.opt_cmd_chain_opts(){
  assert "$(bake._opt_cmd_chain_opts "root")" @is \
"root/opts/debug
root/opts/help"

  # "include parent option"
  assert "$(bake._opt_cmd_chain_opts "bake.opt")" @is \
"bake.opt/opts/abbr
bake.opt/opts/cmd
bake.opt/opts/default
bake.opt/opts/desc
bake.opt/opts/name
bake.opt/opts/required
bake.opt/opts/type
root/opts/debug
root/opts/help"
}


# 查找出所有"tests."开头的函数并执行
# 这种测试有点麻烦，不如bake.test
function test(){
      while IFS=$'\n' read -r functionName ; do
        [[ "$functionName" != tests.* ]] && continue ;
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
      done <<<"$(declare -F | grep "declare -f" | awk {'print $3'})"
}


# todo 模仿http错误
# 报错后终止程序，类似于其他语言的_throw Excpetion
# 因set -o errexit 后，程序将在return 1 时退出，
# 退出前被‘trap bake._on_error ERR’捕获并显示错误堆栈
# Usage: _throw <http_error_code> <ERROR_MESSAGE>
_shell_code_to_http_code(){ return $(($1 + 200)) ; }
_http_code_to_shell_code(){ return $(($1 - 200)) ; }
_todo_throw(){
  local http_code="$1";
  local running_info="${SCRIPT_PATH} -> ${FUNCNAME[1]} ▶︎【$*】"
  if ! (( http_code >301 && http_code <=555  )); then
     echo "$running_info "
     echo "  => error : http_code参数要在301~555之间，模仿http状态码, Usage: _throw <http_code> <ERROR_MESSAGE>"
     return "$(_http_code_to_shell_code "$http_code")"
  fi
  shift
  echo "$running_info"
  # set -o errexit 后，程序将退出，退出前被trap bake._on_error Err捕获并显示错误堆栈
  return "$(_http_code_to_shell_code "$http_code")"
}

# override test
#root(){
#  echo "you can run
#   ./test/$TEST_FILE test -h       # test subcommands
#   ./test/$TEST_FILE test          # or run all test in this file"
#}

bake.cmd --cmd root --desc "
$(cat <<END_DESC

Examples:
./$TEST_FILE test -h       # test list
./$TEST_FILE all           # or run all test in this file"


END_DESC
)
"



bake.go "$@"
