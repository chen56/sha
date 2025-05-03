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
           


# @cmd  (public api)
# 注册一个命令的帮助信息
# Examples:
#   @cmd "sake [options] " --desc "build project"
# 尤其是可以配置root命令以定制根命令的帮助信息，比如:
#   bake.cmd --cmd root \
#             --desc "flutter-note cli."
# 这样就可以用'./your_script -h' 查看根帮助了
@cmd() {
  local __cmd="$1" __desc="$2"

  if [[ "$__cmd" == "" ]]; then
    echo "error, please: @cmd <cmd> [description] " >&2
    return 1
  fi
  _bake_data["$__cmd/desc"]="$__desc"
}