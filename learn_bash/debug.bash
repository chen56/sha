#!/usr/bin/env bash

# PS4 环境变量：PS4 是 Bash shell 中的一个特殊环境变量，它用于定义在调试模式（-x 选项）下显示的次要提示符。
# 默认情况下，PS4 的值是 + （一个加号和一个空格）。可以用定制前缀
# 比如 将 PS4 PS4='Line ${LINENO}: '设置为显示当前执行行的行号，格式为 Line <行号>: 。
# 这里 ${LINENO} 是 Bash 中的一个特殊变量，它会被扩展为当前正在执行的脚本行的行号。
PS4='Line ${LINENO}: ' bash -x  some.bash