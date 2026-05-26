# 示例 2：GPIO LED 驱动 (涉及设备树)

此示例展示了如何编写一个依赖设备树 (Device Tree) 来获取硬件资源（GPIO 引脚）的驱动程序。

## 操作流程

### 1. 修改设备树 (.dts)
在 [linux-fslc/arch/arm/boot/dts/nxp/imx/imx6ull.dtsi](linux-fslc/arch/arm/boot/dts/nxp/imx/imx6ull.dtsi) 或具体的板子文件（如 `imx6ull-14x14-evk.dts`）的根节点 `/` 下添加：

```dts
/ {
    my_led {
        compatible = "my-project,gpio-led";
        led-gpios = <&gpio1 3 GPIO_ACTIVE_HIGH>; /* 假设使用的是 GPIO1_IO03 */
        status = "okay";
    };
};
```
*注：具体引脚请根据你的开发板原理图修改。*

### 2. 编译设备树
执行以下命令生成新的 `.dtb` 文件：
```bash
cd linux-fslc
make dtbs ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
```
产物：`arch/arm/boot/dts/nxp/imx/imx6ull-*.dtb`。你需要将此文件烧录到开发板的 `/boot` 分区并重启。

### 3. 编译驱动模块
在 `drivers/02_gpio_led/` 目录下执行：
```bash
make
```
产物：`drv_led.ko`

### 4. 运行与验证
1.  加载驱动：`insmod drv_led.ko`
2.  查看内核日志：`dmesg | tail`，确认是否探测到了设备。
3.  观察硬件：LED 是否点亮。
4.  卸载驱动：`rmmod drv_led` (LED 应该会熄灭)。

## 核心知识点
- **Compatible 匹配**: 驱动中的 `.compatible = "my-project,gpio-led"` 必须与设备树中的该字符串完全一致，内核才会调用驱动的 `probe` 函数。
- **OF API**: 使用 `of_get_named_gpio` 等函数从设备树节点中直接提取引脚配置，使驱动程序与硬件引脚号解耦，更具通用性。
