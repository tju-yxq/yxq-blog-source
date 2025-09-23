---
title:       "计算机系统基础1 笔记1"
subtitle:    ""
layout:      "single"
description: "Linux和git的命令笔记"
date:        {{.Date}}
author:      "yxq"
image:       "img/dzq/1.png"
tags:        ["计算机系统"]
categories:  ["计算机系统"]
---

### Linux 命令笔记

#### 一、文件和目录操作

- **`ls`**：列出目录内容

  - `ls -a`：显示隐藏文件（以 `.` 开头）
  - `ls -l`：显示文件和目录的详细属性（权限、所有者等）

- **`cd`**：切换目录

  ```bash
  cd /path/to/directory  # 进入指定目录
  ```

- **`pwd`**：显示当前工作目录路径

- **`mkdir`**：创建目录

  ```bash
  mkdir test          # 创建 test 目录
  mkdir -p test1/test2  # 递归创建 test1 和 test1/test2 目录
  ```

- **`rmdir`**：删除空目录

  ```bash
  rmdir test          # 删除空目录 test
  rmdir test1/test2   # 删除 test1/test2 空目录
  ```

- **`*`**：通配符（匹配任意字符）

  ```bash
  ls *.txt           # 列出所有 .txt 文件
  ```

- **`cp`**：复制文件/目录

  ```bash
  cp file /usr/men/tmp/file1   # 复制文件并重命名
  cp -rf /usr/men /usr/zh      # 递归复制目录（含子目录）
  cp -rf test/* test1          # 强制复制 test 下所有内容到 test1
  cp -i /usr/men/m*.c /usr/zh  # 交互式复制（覆盖前确认）
  ```

- **`rm`**：删除文件/目录

  ```bash
  rm f1              # 删除文件 f1
  rm f1 f2           # 删除多个文件
  rm -rf test        # 强制递归删除目录（慎用！）
  ```

- **`mv`**：移动/重命名

  ```bash
  mv f1 f2 test      # 移动文件到目录
  mv f1 test/f3      # 移动并重命名
  mv f1 f4           # 重命名文件
  ```

---

#### 二、权限管理

- **权限格式**：`-rwxrwxrwx`

  - `r`=读, `w`=写, `x`=执行
  - 三组权限：所有者(`u`)、所属组(`g`)、其他人(`o`)

- **`chmod`**：修改权限

  ```bash
  chmod a+r file      # 所有用户添加读权限
  chmod a-r file      # 所有用户移除读权限
  chmod u=rw,go= file # 所有者读写，其他用户无权限
  ```

---

#### 三、文件链接

- **`ln`**：创建链接

  ```bash
  ln 1.log 2.log        # 创建硬链接
  ln -s 1.log 2.log     # 创建软链接（符号链接）
  ln -sf 1.log 2.log    # 强制覆盖现有链接
  ```

  - **硬链接**：直接指向文件数据
  - **软链接**：类似快捷方式（源文件删除则失效）

---

#### 四、文件查看与搜索

- **查看文件内容**：

  ```bash
  cat file.txt       # 输出全文到控制台
  objdump file       # 查看 ELF 可执行文件结构
  more file.txt      # 分页显示
  ```

- **搜索文件/内容**：

  ```bash
  find ./test1 -name "a.txt"     # 按文件名搜索
  find ./test1 -name "*.cpp"     # 通配符搜索
  grep "hello" file.txt         # 查找文件中的文本
  grep main -r *.cpp            # 递归搜索目录中的内容
  ```

---

### GNU 工具链

#### 一、GCC 编译器

- **基本用法**：

  ```bash
  gcc *.c                  # 编译链接（输出 a.out）
  gcc -o program *.c       # 指定输出文件名
  gcc -c a.c b.c           # 只编译不链接（生成 .o）
  gcc -o program a.o b.o   # 链接目标文件
  ```

- **高级选项**：

  ```bash
  gcc -c a.c -Iinc         # 指定头文件目录
  gcc -o program a.o -lm   # 链接数学库
  ```

#### 二、GDB 调试器

- **调试流程**：

  ```bash
  gdb program              # 启动调试
  (gdb) b main.c:10        # 在 main.c 第 10 行设断点
  (gdb) p variable         # 打印变量值
  (gdb) s                  # 单步执行
  (gdb) continue           # 继续运行到下一断点
  (gdb) q                  # 退出
  ```

---

> **说明**：
>
> - 文件打包（`tar`）、`Binutils` 工具链（`as`, `ld`, `objcopy`）和 `Make` 构建工具未详细展开。
> - 使用 `sudo` 需谨慎，避免权限误操作。
