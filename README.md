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

### 1.2 交叉编译器
本项目使用标准的 ARM 32 位交叉编译器：`arm-linux-gnueabihf-`。

## 2. 工程结构
- `linux-fslc/`: Linux 内核源码（子模块）。
- `CHANGELOG.md`: 项目更新日志。
- `.gitignore`: 忽略编译产生的临时文件。

## 3. 构建与编译指南

### 3.1 环境变量配置
为了简化后续命令，建议在当前终端设置以下环境变量：
```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
```

### 3.2 初始化配置
进入内核目录并应用 i.MX6 系列的默认配置文件：
```bash
cd linux-fslc
make mrproper      # 清理之前的残留配置
make imx_v7_defconfig
```
*注意：如果是第一次在新环境编译，建议运行 `make olddefconfig` 以自动处理新版本内核的默认配置。*

### 3.3 切换内核版本
由于 `linux-fslc` 是作为一个 Git 仓库存在的，你可以随时切换到不同的分支或标签：
```bash
cd linux-fslc
git checkout 6.18-1.0.x-imx          # 切换到指定版本
```

### 3.4 菜单配置 (可选)
如果需要自定义内核功能或驱动：
```bash
make menuconfig
```

### 3.4 开始编译
使用全速编译（`-j` 参数建议设为 CPU 核心数）：
```bash
make zImage modules dtbs -j$(nproc)
```

## 4. 产物路径
编译完成后，关键文件位于以下路径：
- **内核镜像**: `linux-fslc/arch/arm/boot/zImage`
- **设备树文件**: `linux-fslc/arch/arm/boot/dts/nxp/imx/imx6ull-*.dtb`
- **驱动模块**: 位于各级子目录下的 `.ko` 文件。

## 5. 常见问题记录
- **缺少 ncurses**: 若满足不了 `menuconfig` 的运行环境，请确保已安装 `libncurses-dev`。
- **配置项询问**: 升级内核版本后运行编译若出现大量 `(NEW)` 询问，请先执行 `make olddefconfig`。
- **清理工程**: 
    - `make clean`: 删除编译生成物，保留配置文件。
    - `make mrproper`: 彻底清理，恢复至源码初始状态。

