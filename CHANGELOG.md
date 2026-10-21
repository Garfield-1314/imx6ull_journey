# 更新日志 (CHANGELOG)

所有对本项目的显著更改都将记录在此文件中。

## 2026-10-21

### 已变更
- 全量补全根目录 [README.md](README.md)，合并 `main` 分支与 `feature/driver-development` 分支两版内容，修复章节编号重复问题。

### 已添加
- 新增「快速开始」章节：从克隆仓库、拉取子模块到跑通第一个驱动示例的最短闭环步骤。
- 补回 `main` 分支中缺失的章节：获取子模块 (`git submodule init/update`)、工程结构目录导航、切换内核版本、`menuconfig` 菜单配置、全量编译 (`make zImage modules dtbs`)、产物路径说明。
- FAQ 补充 `ncurses` 缺失、`(NEW)` 询问使用 `olddefconfig`、`make clean` 与 `make mrproper` 区别等条目。

## 2026-05-26

### 已添加
- 初始化工程，引入 NXP i.MX 系列 Linux 内核源码 (`linux-fslc`)。
- 在根目录添加 `.gitignore` 文件，忽略编辑器及编译产生的临时文件。
- 创建此 `CHANGELOG.md` 文件用于记录开发进程。
- 新增杂项字符设备驱动示例 ([drivers/01_chrdev_misc/](drivers/01_chrdev_misc/))，演示 `miscdevice` 框架及无需设备树的简单驱动实现。
- 新增 GPIO LED 驱动示例 ([drivers/02_gpio_led/](drivers/02_gpio_led/))，演示基于设备树 (Device Tree) 的硬件资源管理与 `OF API` 编程。
- 为驱动目录添加了完善的 `README.md` 教程，明确编译、拷贝、运行及验证的完整闭环。

### 已变更
- 生成了 i.MX6ULL 的默认配置文件 `.config` (基于 `imx_v7_defconfig`)。
- 优化了配置选项，使用 `olddefconfig` 处理了新内核特性的确认问题。
- 重构了驱动示例代码，优化了模块初始化与资源释放的逻辑。

### 已修复
- 解决了编译时因缺少 `ncurses` 库导致 `menuconfig` 无法运行的问题。
