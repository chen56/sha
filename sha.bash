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

# 当前命令层级的命令列表，key是命令名，value是命令名
declare -A _sha_all_cmds
declare -A _sha_current_cmds
# 当前命令层级
declare _sha_cmd_levels=()
declare _sha_no_cmd_prefixes=("_" "fn_" "sha") # 示例前缀数组

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

# 关联数组不像普通数组那样可以: a=() 清理，所以需要自己清理
# Usage: _sha_clear_associative_array <array_name>
_sha_clear_associative_array() {
    # --- 参数及错误检查 ---

    # 检查是否提供了恰好一个参数 (关联数组的名称)
    if [ "$#" -ne 1 ]; then
        echo "用法: ${FUNCNAME[0]} <关联数组名称>" >&2 # ${FUNCNAME[0]} 获取当前函数名
        echo "示例: ${FUNCNAME[0]} my_data_array" >&2
        return 1
    fi

    local array_name="$1" # 从第一个参数获取关联数组的名称

    # 使用 'declare -n' 创建一个名称引用 (nameref)
    # 这使得 'arr_ref' 成为一个指向由 $array_name 指定的实际关联数组的别名
    # 对 arr_ref 的任何操作都会直接作用于原始关联数组
    # requires Bash 4.3+
    declare -n arr_ref="$array_name"

    # 检查由 $array_name 指定的变量是否存在且是否确实是一个关联数组
    # declare -p 会打印变量的属性，grep -q 检查输出是否包含 "declare -A"
    # 2>/dev/null 忽略当变量不存在时 declare -p 可能输出的错误信息
    if ! declare -p "$array_name" 2>/dev/null | grep -q "declare -A"; then
         echo "错误: 变量 '$array_name' 不存在或不是一个已声明的关联数组。" >&2
         return 1
    fi

    # 获取数组的所有键的列表，并循环遍历
    # "${!arr_ref[@]}" 通过名称引用获取原始关联数组的所有键
    for key in "${!arr_ref[@]}"; do
        # 使用 unset 命令删除当前键对应的元素
        # "arr_ref["$key"]" 通过名称引用访问原始关联数组的元素
        unset 'arr_ref["$key"]'
    done
}


# Usage: _sha_register_next_level_cmds <cmd_level>
# ensure all cmd register
# root cmd_level is "/"
_sha_register_next_level_cmds() {
  local next_level="$1"

  _sha_cmd_levels+=("$next_level")

  # 每次清空，避免重复注册，目前的简化模型，只注册当前层级命令，不注册子命令
  declare -A next_level_cmds
  local funcName
  while IFS=$'\n' read -r funcName; do
    if [[ "$funcName" == */* ]]; then
      _sha_log ERROR "function name $funcName() can not contains '/' " >&2
      return 1
    fi

    # 新增的cmd才是下一级的cmd
    if [[ "${_sha_all_cmds["$funcName"]}" != "" ]]; then
      continue;
    fi
    
    local p
    local starts_with_any_prefix=false

    for p in "${_sha_no_cmd_prefixes[@]}" ;do
      # 只要匹配一个非cmd前缀，就不注册cmd
      if [[ "$funcName" = "$p"* ]]; then
        starts_with_any_prefix=true
        break;
      fi
    done

    if ! $starts_with_any_prefix ; then
        next_level_cmds["$funcName"]="$funcName"
    fi



  # declare -F | grep "declare -f"  列出函数列表
  #   =>  declare -f bake.cmd
  # cut :
  #    -d " "      => 指定delim分割符
  #    -f 3        => 指定list列出第3个字段即函数名
  done <<< "$(declare -F | grep "declare -f" | cut -d " " -f 3) "

  # 填充为下一级命令列表
  # 设置下一级的命令列表前先清空上一级列表
  _sha_clear_associative_array _sha_current_cmds
  # "${!next_level_cmds[@]}" 会扩展为关联数组的所有键的列表
  for key in "${!next_level_cmds[@]}"; do
      _sha_all_cmds["$key"]="${next_level_cmds["$key"]}"
      _sha_current_cmds["$key"]="${next_level_cmds["$key"]}"
  done  

}

_sha_help() {
  echo "###########################"
  echo "## she help"
  echo "###########################"
  for key in "${!_sha_current_cmds[@]}"; do
      echo "$key" : "${_sha_current_cmds[$key]}"
  done  
}

# cmd  (public api)
# 注册一个命令的帮助信息
# Examples:
#   cmd "sha [options] " --desc "build project"
# 尤其是可以配置root命令以定制根命令的帮助信息，比如:
#   cmd --cmd root \
#             --desc "flutter-note cli."
# 这样就可以用'./your_script -h' 查看根帮助了
# cmd() {
#   local __cmd="$1" __desc="$2"

#   if [[ "$__cmd" == "" ]]; then
#     echo "error, please: @cmd <cmd> [description] " >&2
#     return 1
#   fi
# }


_sha_is_leaf_cmd() {
  if [[ "${#_sha_current_cmds[@]}" == "0" ]]; then
    return 0;
  fi
  return 1;
}




_sha() {
  local cmd="$1"
  # echo "_sha(): args:[$*] , current_cmds:[${_sha_all_cmds[*]}]"
  shift

  # 合法命令先执行
  if [[  "${_sha_current_cmds[$cmd]}" == "" ]]; then
    echo  "ERROR: unknown command $cmd, 请使用 './sha --help' 查看可用的命令。 "
    exit 1;
  fi
  
  # 执行当前命令后，再注册当前命令的子命令
  "$cmd" "$@"
  _sha_register_next_level_cmds "$cmd"

  # 根命令本身就是leaf，返回即可
  if _sha_is_leaf_cmd; then
    return 0;
  fi

  # not leaf cmd, no args, help
  if (( $#==0 )); then
    _sha_help
    echo "请使用子命令, 例如: ./sha <cmd> [args]"
    exit 3;
  fi

  # 后面还有参数,递归处理
  _sha "$@"
}

sha() {
  _sha_register_next_level_cmds "/"

  # 根命令本身就是leaf，返回即可
  if _sha_is_leaf_cmd; then
    return 0;
  fi

  # not leaf cmd, no args, help
  if (( $#==0 )); then
    _sha_help
    echo "请使用子命令, 例如: ./sha <cmd> [args]"
    exit 3;
  fi
  # not leaf cmd, has args, process args
  _sha "$@"
}

#######################################
## 入口
#######################################
trap "_sha_on_error" ERR
