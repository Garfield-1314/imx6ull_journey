# 更新日志 (CHANGELOG)

所有对本项目的显著更改都将记录在此文件中。

## 2026-10-22

### 已添加
- 新增 [`dts/`](dts/) 目录存放自定义设备树源文件，首个文件为 [dts/imx6ull-garfield.dts](dts/imx6ull-garfield.dts)。
  - 继承官方 `imx6ull-14x14-evk.dts`，新增 `my_led` 节点（`compatible = "my-project,gpio-led"`）供 [drivers/02_gpio_led/](drivers/02_gpio_led/) 绑定。
  - LED 使用 `GPIO1_IO18`（pad `UART1_CTS_B`），并在 `&iomuxc` 中补充 `pinctrl_my_led` 完成 mux，避开 EVK 已被触摸屏占用的 `GPIO1_IO01~04`。

### 已变更
- [README.md](README.md) 4.2 节重写自定义设备树流程：源文件改由主仓库维护，编译前手动 `cp` 进内核树，**不再修改内核子模块的 `Makefile`**。
  - 依据：`.dtb` 的生成规则是无条件模式规则 `$(obj)/%.dtb: $(obj)/%.dts`，只要同名 `.dts` 存在即可编译，`dtb-$(...)` 注册仅影响 `make dtbs` 全量编译是否包含该条目。
  - 由此内核子模块 `linux-fslc/` 保持与官方完全一致，无任何已跟踪文件被改动。
- 修正 README 中自定义设备树的错误说法：原写作「在 `dtb-$(CONFIG_ARCH_MXC)` 中注册」，而 `nxp/imx/Makefile` 全文只使用 SoC 级符号（如 `CONFIG_SOC_IMX6UL`），`CONFIG_ARCH_MXC` 出现 0 次。
- 更新 [README.md](README.md) 第 2 节工程结构与第 6 节产物路径，补充 `dts/` 目录说明及自定义设备树的单独编译步骤。

### 已修复
- 修复 README 中「自定义设备树需先创建文件、再注册 Makefile」的误导性描述 —— 报错 `No rule to make target 'xxx.dtb'` 的真实原因是同名 `.dts` 不存在，而非未在 `Makefile` 注册。

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
