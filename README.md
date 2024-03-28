# bake


```bash

# v0.2.20230528 - It can run normally on macos
# bake == (bash)ake == 去Make的bash tool
# 
# https://github.com/chen56/bake
#
# bake 是个简单的命令行工具，以替代Makefile的子命令功能
# make工具的主要特点是处理文件依赖进行增量编译，但flutter、golang、java、js项目的build工具
# 太厉害了，这几年唯一还在用Makefile的理由就是他的子命令机制: "make build"、
# "make run", 可以方便的自定义单一入口的父子命令，但Makefile本身的语法套路也很复杂，
# 很多批处理还是要靠bash, 这就尴尬了，工具太多，麻烦！本脚本尝试彻底摆脱使用Makefile。
# 经尝试，代码很少啊 ，核心代码几百行啊，父子命令二三百行左右，option解析二三百行左右，功能足够了：
#
# bake命令规则：
# 1. 函数即命令，所有bake内的函数均可以在脚本外运行：
#      ./bake [all function]     # bake内的所有函数均可以在脚本外直接运行
#      ./bake info               # 比如这个内部函数, 看bake内部变量，调试脚本用
#      ./bake test               # 你如果定义过test()函数，就可以这样运行
# 2. 带"."的函数，形成父子命令:
#    web.build(){ echo "build web app"; }
#    web.test(){ echo "build web app"; }
#   可以这样调用
#      ./bake web -h            # 运行子命令,或看帮助
#      ./bake web.build -h      # 上面等同
#      ./bake web test -h       # 运行子命令,或看帮助
#      ./bake web.test -h       # 与上面等同
# 3. 特殊的root命令表示根命令
#      ./bake                   # 如果有root()函数，就执行它
# 4. 像其他高级语言的cli工具一样，用简单变量就可以获取命令option:
#    # a. 先在bake文件里里定义app options
#      bake.opt --cmd build --name "target" --type string
#    # b. 解析和使用option
#      function build() {
#         eval "$(bake.parse "${FUNCNAME[0]}" "$@")";
#         echo "build ... your option：target: $target";
#      }
#    # c. 调用看看:
#      ./bake build --target "macos"
# 5. bake尽量不依赖bash以外的其他工具，包括linux coreutils,更简单通用,但由于用了关联数组等
#    依赖bash4+
# 6. 有两种用法：
#     - 这个文件copy走，把你的脚本放到本脚本最后即可.
#     - 在你的脚本里直接curl下载本脚本后 source即可。
# 范例可以看实际案例：
#     - https://github.com/chen56/note/blob/main/bake
#     - https://github.com/chen56/younpc/blob/main/bake
# todo
#   1. 当前 无法判断错误命令：./bake no_this_cmd ,因为不知道这是否是此命令的参数，
#      需要设置设一个简单的规则：只有叶子命令才能正常执行，这样非叶子命令就不需要有参数
#   2. 当前 无法判断错误options：./bake --no_this_opt ,同上
#   3. 类似flutter run [no-]pub 反向选项
# 


```