# imx6ull_journey

![build](https://github.com/Garfield-1314/imx6ull_journey/actions/workflows/ci.yml/badge.svg?branch=main)

i.MX6ULL 嵌入式 Linux 学习与开发笔记。本项目基于 NXP 官方维护的 `linux-fslc` 内核源码，旨在记录 i.MX6ULL 的内核编译、驱动开发及系统移植过程。

## 0. 快速开始

从零环境到跑通第一个驱动示例的最短闭环（详细步骤见后续章节）：

```bash
# 1. 克隆工程并拉取内核子模块
git clone <repo-url> imx6ull_journey
cd imx6ull_journey
git submodule init && git submodule update --progress

# 2. 安装依赖并配置交叉编译环境 (见 1.1 / 1.3)
sudo apt-get update
sudo apt-get install build-essential libncurses-dev pkg-config \
                     flex bison libssl-dev libelf-dev \
                     gcc-arm-linux-gnueabihf git
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

# 3. 生成内核配置 (见 3.2)
cd linux-fslc
make mrproper
make imx_v7_defconfig
make olddefconfig

# 4. 准备外部驱动编译所需的头文件与符号表 (见 3.5)
make modules_prepare
make modules -j$(nproc)
cd ..

# 5. 编译第一个驱动示例 (见 4.1)
cd drivers/01_chrdev_misc
make

# 6. 拷贝到开发板并验证 (见 5)
scp drv_misc.ko root@<板子IP>:~
# 板子上：
insmod drv_misc.ko
cat /dev/my_misc_dev     # 输出：Hello from kernel!
rmmod drv_misc
```

若要跑通第二个示例（GPIO LED，涉及设备树），请继续按照 [drivers/02_gpio_led/](drivers/02_gpio_led/) 的说明操作。

---

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

### 1.3 环境变量
```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
```

### 1.4 获取子模块
内核源码 `linux-fslc/` 以 Git 子模块形式引入，首次克隆后必须拉取：
```bash
git submodule init
git submodule update --progress
```

---

## 2. 工程结构

- [`linux-fslc/`](linux-fslc/): Linux 内核源码（Git 子模块，来自 NXP 维护的 `Freescale/linux-fslc`）。
- [`dts/`](dts/): 自定义设备树源文件（主仓库维护，编译前复制进内核树，见 4.2 节）。
- [`drivers/01_chrdev_misc/`](drivers/01_chrdev_misc/): 示例 1 —— 杂项字符设备驱动（无需修改设备树）。
- [`drivers/02_gpio_led/`](drivers/02_gpio_led/): 示例 2 —— GPIO LED 驱动（基于设备树）。
- [`CHANGELOG.md`](CHANGELOG.md): 项目更新日志。
- [`.gitignore`](.gitignore): 忽略编辑器及编译产生的临时文件。

---

## 3. 内核编译流程

### 3.1 切换内核版本
由于 `linux-fslc` 是一个独立的 Git 仓库，可以随时切换到不同的分支或标签：
```bash
cd linux-fslc
git checkout 6.18-1.0.x-imx          # 切换到指定版本
```

### 3.2 初始化配置
```bash
cd linux-fslc
make mrproper      # 彻底清理 (注意：这会删除所有生成的头文件和配置)
make imx_v7_defconfig
make olddefconfig  # 自动处理新版本内核新增配置项的确认，避免编译时出现大量 (NEW) 询问
```

### 3.3 菜单配置 (可选)
如果需要自定义内核功能或驱动：
```bash
make menuconfig
```

### 3.4 全量编译
使用全速编译（`-j` 参数建议设为 CPU 核心数）：
```bash
make zImage modules dtbs -j$(nproc)
```

### 3.5 外部驱动前置准备 (关键坑点)

在开发自己的外部驱动之前，**必须**确保内核源码处于已配置且已编译的状态，否则会遇到各种头文件和符号缺失的问题。

1. **生成头文件**: `make modules_prepare`
   - *修复坑: `asm-offsets.h` 缺失及 `stack-protector` 参数错误。*
2. **生成符号表**: `make modules -j$(nproc)`
   - *修复坑: `modpost: "xxx" undefined!` 错误。因为外部驱动需要链接内核导出的符号表 `Module.symvers`，该文件仅在编译过内核模块后生成。*

---

## 4. 自定义外设驱动开发流程

### 4.1 编写驱动
- **方式 A (不改设备树)**: 参考 [drivers/01_chrdev_misc/](drivers/01_chrdev_misc/)，使用 `miscdevice` 框架。
- **方式 B (修改设备树)**: 参考 [drivers/02_gpio_led/](drivers/02_gpio_led/)，使用 `platform_driver` 框架。

### 4.2 自定义设备树 (DTS)

**源文件在主仓库 [`dts/`](dts/) 目录维护**，内核子模块 `linux-fslc/` 保持官方原样不作任何改动；编译前手动复制进内核树即可。

1. **源文件**: [`dts/imx6ull-garfield.dts`](dts/imx6ull-garfield.dts)
   - 用 `#include "imx6ull-14x14-evk.dts"` 继承官方设备树，只添加自己的节点，**不要**直接修改官方 `.dts`。
   - **引脚 mux**: 若节点用到 GPIO，需在 `&iomuxc` 下定义对应 `pinctrl_*` 组并挂到节点的 `pinctrl-0`，否则 pad 仍是复位默认功能，驱动取不到 GPIO。
2. **复制 + 编译**:
   ```bash
   cp dts/imx6ull-garfield.dts linux-fslc/arch/arm/boot/dts/nxp/imx/
   cd linux-fslc
   make nxp/imx/imx6ull-garfield.dtb
   ```
3. **产物**: `linux-fslc/arch/arm/boot/dts/nxp/imx/imx6ull-garfield.dtb`

> **为什么不用改内核 Makefile**: `.dtb` 的生成规则是无条件的模式规则 `$(obj)/%.dtb: $(obj)/%.dts`，只要同名 `.dts` 存在即可编译，与 `Makefile` 里的 `dtb-$(...)` 注册无关。
> 唯一的区别是 `make dtbs` 全量编译不会带上它（`dtb-y` 中没有该条目），需要单独执行上面的单文件编译命令。
>
> 复制进去的 `.dts` 在子模块中属于 untracked 文件，会显示 `?? imx6ull-garfield.dts`。若不想看到，可执行一次：
> ```bash
> echo '/imx6ull-garfield.dts' >> "$(git -C linux-fslc rev-parse --git-path info/exclude)"
> ```
> 编译完成后直接 `rm linux-fslc/arch/arm/boot/dts/nxp/imx/imx6ull-garfield.dts` 也可以。

---

## 5. 烧录与运行

1. **设备树**: 将生成的 `.dtb` 拷贝到板子 `/boot` 目录，并在 U-Boot 中指定 `setenv fdt_file imx6ull-garfield.dtb`。
2. **驱动**: `scp` 拷贝 `.ko` 文件。
3. **加载**: `insmod xxx.ko`。
4. **卸载**: `rmmod xxx`。

---

## 6. 产物路径

编译完成后，关键文件位于以下路径：

- **内核镜像**: `linux-fslc/arch/arm/boot/zImage`
- **设备树源码**: `dts/imx6ull-garfield.dts`（主仓库）
- **设备树编译产物**: `linux-fslc/arch/arm/boot/dts/nxp/imx/imx6ull-*.dtb`
  （自定义设备树为 `imx6ull-garfield.dtb`，需先按 4.2 节复制源文件再单独编译）
- **驱动模块**: 位于各级子目录下的 `.ko` 文件，如 `drivers/01_chrdev_misc/drv_misc.ko`、`drivers/02_gpio_led/drv_led.ko`。

---

## 7. 常见问题记录 (FAQ)

- **编译驱动报错 `undefined!`**: 这是因为内核没有生成 `Module.symvers`。请先在 `linux-fslc` 目录下运行 `make modules`。
- **编译驱动报错 `asm-offsets.h` 缺失**: 请确保执行了 `make modules_prepare`。
- **驱动 `remove` 函数报错**: 新版内核 (6.x+) 中，`platform_driver.remove` 的返回类型改为 `void`。请确保驱动代码中不含 `return 0;`。
- **修改设备树后 `probe` 不执行**: 检查驱动的 `compatible` 字符串是否与设备树完全匹配，以及板子是否加载了正确的 `.dtb` 文件（可通过 `cat /proc/device-tree/model` 验证）。
- **缺少 ncurses 导致 `menuconfig` 无法运行**: 请确保已安装 `libncurses-dev`。
- **配置项询问大量 `(NEW)`**: 升级内核版本后运行编译若出现大量 `(NEW)` 询问，请先执行 `make olddefconfig`。
- **清理工程**:
    - `make clean`: 删除编译生成物，保留配置文件。
    - `make mrproper`: 彻底清理，恢复至源码初始状态。

---

## 8. 持续集成 (GitHub Actions)

流水线配置见 [`.github/workflows/ci.yml`](.github/workflows/ci.yml)，在 **push 到 `main`** 或 **提交 PR** 时自动运行（手动触发可用 Actions 页面的 `Run workflow`）。

它会在 GitHub 提供的临时 Ubuntu 机器上自动完成：

1. 浅克隆主仓库与 `linux-fslc` 子模块
2. 安装交叉工具链与内核编译依赖
3. `imx_v7_defconfig` + `modules_prepare` + `make modules`（生成 `Module.symvers`）
4. `checkpatch.pl` 风格检查（当前不阻塞构建）
5. 编译 `dts/imx6ull-garfield.dts`
6. 编译 `drivers/*/` 下的全部外部驱动
7. 上传 `.ko` 与 `.dtb` 作为构建产物（Artifacts）

**查看结果**：仓库顶部 `Actions` 标签 → 选择 `build` → 点开对应运行。绿勾表示成功，红叉点进去可看到具体报错。

**缓存策略**：以 `linux-fslc` 子模块的 commit SHA 作为 ccache 缓存 key。内核版本不变时，后续运行只重编驱动和设备树，耗时从首次的 20+ 分钟降到几分钟。升级内核后首次运行会重新全量编译，属正常现象。

> 说明：CI 只验证「能编译」，无法替代开发板上的实际加载测试。
