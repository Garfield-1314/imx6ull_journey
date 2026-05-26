# imx6ull_journey

i.MX6ULL 嵌入式 Linux 学习与开发笔记。本项目基于 NXP 官方维护的 `linux-fslc` 内核源码，旨在记录 i.MX6ULL 的内核编译、驱动开发及系统移植过程。

## 1. 环境准备

### 1.1 依赖软件包安装
在 Ubuntu/Debian 系统下，执行以下命令安装必要的构建工具和库：
```bash
sudo apt-get update
sudo apt-get install build-essential libncurses-dev pkg-config \
                     flex bison libssl-dev libelf-dev \
                     gcc-arm-linux-gnueabihf git
```

### 1.2 环境变量
```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
```

---

## 2. 内核基础编译流程 (关键坑点)

在开发自己的外部驱动之前，**必须**确保内核源码处于已配置且已编译的状态，否则会遇到各种头文件和符号缺失的问题。

### 2.1 初始化配置
```bash
cd linux-fslc
make mrproper      # 彻底清理 (注意：这会删除所有生成的头文件和配置)
make imx_v7_defconfig
```

### 2.2 核心准备步骤
1. **生成头文件**: `make modules_prepare` 
   - *修复坑: `asm-offsets.h` 缺失及 `stack-protector` 参数错误。*
2. **生成符号表**: `make modules -j$(nproc)` 
   - *修复坑: `modpost: "xxx" undefined!` 错误。因为外部驱动需要链接内核导出的符号表 `Module.symvers`，该文件仅在编译过内核模块后生成。*

---

## 3. 自定义外设驱动开发流程

### 3.1 编写驱动
- **方式 A (不改设备树)**: 参考 [drivers/01_chrdev_misc/](drivers/01_chrdev_misc/)，使用 `miscdevice` 框架。
- **方式 B (修改设备树)**: 参考 [drivers/02_gpio_led/](drivers/02_gpio_led/)，使用 `platform_driver` 框架。

### 3.2 自定义设备树 (DTS)
**不要**直接修改官方 `.dts`，推荐创建独立文件：
1. **新建文件**: 在 `arch/arm/boot/dts/nxp/imx/` 创建 `imx6ull-garfield.dts`。
2. **内容继承**: `#include "imx6ull-14x14-evk.dts"` 并添加自己的节点。
3. **Makefile 注册**: 修改同目录下的 `Makefile`，添加 `dtb-$(CONFIG_ARCH_MXC) += imx6ull-garfield.dtb`。
4. **精确编译**:
   ```bash
   make nxp/imx/imx6ull-garfield.dtb
   ```

---

## 4. 烧录与运行

1. **设备树**: 将生成的 `.dtb` 拷贝到板子 `/boot` 目录，并在 U-Boot 中指定 `setenv fdt_file imx6ull-garfield.dtb`。
2. **驱动**: `scp` 拷贝 `.ko` 文件。
3. **加载**: `insmod xxx.ko`。
4. **卸载**: `rmmod xxx`。

---

## 5. 常见问题记录 (FAQ)

- **编译驱动报错 `undefined!`**: 这是因为内核没有生成 `Module.symvers`。请先在 `linux-fslc` 目录下运行 `make modules`。
- **编译驱动报错 `asm-offsets.h` 缺失**: 请确保执行了 `make modules_prepare`。
- **驱动 `remove` 函数报错**: 新版内核 (6.x+) 中，`platform_driver.remove` 的返回类型改为 `void`。请确保驱动代码中不含 `return 0;`。
- **修改设备树后 `probe` 不执行**: 检查驱动的 `compatible` 字符串是否与设备树完全匹配，以及板子是否加载了正确的 `.dtb` 文件（可通过 `cat /proc/device-tree/model` 验证）。
