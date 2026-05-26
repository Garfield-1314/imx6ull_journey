# 更新日志 (CHANGELOG)

所有对本项目的显著更改都将记录在此文件中。

## [未发布] - 2026-05-26

### 已添加
- 初始化工程，引入 NXP i.MX 系列 Linux 内核源码 (`linux-fslc`)。
- 在根目录添加 `.gitignore` 文件，忽略编辑器及编译产生的临时文件。
- 创建此 `CHANGELOG.md` 文件用于记录开发进程。

### 已变更
- 生成了 i.MX6ULL 的默认配置文件 `.config` (基于 `imx_v7_defconfig`)。
- 优化了配置选项，使用 `olddefconfig` 处理了新内核特性的确认问题。

### 已修复
- 解决了编译时因缺少 `ncurses` 库导致 `menuconfig` 无法运行的问题。
