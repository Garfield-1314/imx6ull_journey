# 更新日志 (CHANGELOG)

所有对本项目的显著更改都将记录在此文件中。

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
