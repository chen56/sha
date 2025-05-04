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
           
_sha_real_path() {  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}" ; }

declare -A _sha_cmds



# replace $HOME with "~"
# Usage: _sha_pwd <path>
# Examples:  
#  _sha_pwd "/home/chen/git/note/"
#         ===> "~/git/note/"
_sha_pwd() {
  local _path="$1"
  printf "%s" "${_path/#$HOME/\~}" ; 
}

# Usage: _sha_log <log_level> <msg...>
# Examples: 
#   _sha_log ERROR "错误消息"
#
# log_level: DEBUG|INFO|ERROR|FATAL
_sha_log(){
  local level="$1"
  echo -e "$level $(date "+%F %T") $(_sha_pwd "$PWD")\$ ${FUNCNAME[1]}() : $*" >&2
}

_sha_on_error() {
  _sha_log ERROR "trapped an error: ↑ , trace: ↓"
  local i=0
  local stackInfo
  while true; do
    stackInfo=$(caller $i 2>&1 && true) && true
    if [[ $? != 0 ]]; then return 0; fi

    # 一行调用栈 '97 bake.build ./note/bake'
    #    解析后 =>  行号no=97 , 报错的函数func=bake.build , file=./note/bake
    local no func file
    IFS=' ' read -r no func file <<<"$stackInfo"

    # 打印出可读性强的信息:
    #    => ./note/bake:38 -> bake.build
    printf "%s\n" "$(_sha_real_path $file):$no -> $func" >&2

    i=$((i + 1))
  done
}

# Usage: bake.__cmd_register
# ensure all cmd register
_sha_cmd_register() {
  local functionName

  while IFS=$'\n' read -r functionName; do
    if [[ "$functionName" == */* ]]; then
      echo "error: function $functionName() can not contains '/' " >&2
      return 1
    fi
    _sha_cmds["$functionName"]="$functionName"

  # declare -F | grep "declare -f"  列出函数列表
  #   =>  declare -f bake.cmd
  # cut :
  #    -d " "      => 指定delim分割符
  #    -f 3        => 指定list列出第3个字段即函数名
  done <<< "$(declare -F | grep "declare -f" | cut -d " " -f 3) "
}


# @cmd  (public api)
# 注册一个命令的帮助信息
# Examples:
#   @cmd "sake [options] " --desc "build project"
# 尤其是可以配置root命令以定制根命令的帮助信息，比如:
#   bake.cmd --cmd root \
#             --desc "flutter-note cli."
# 这样就可以用'./your_script -h' 查看根帮助了
# @cmd() {
#   local __cmd="$1" __desc="$2"

#   if [[ "$__cmd" == "" ]]; then
#     echo "error, please: @cmd <cmd> [description] " >&2
#     return 1
#   fi
# }

sha() {
  echo "$@"
  _sha_cmd_register

  
}

#######################################
## 入口
#######################################
trap "_sha_on_error" ERR
