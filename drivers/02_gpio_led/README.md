# 示例 2：GPIO LED 驱动 (涉及设备树)

此示例展示了如何编写一个依赖设备树 (Device Tree) 来获取硬件资源（GPIO 引脚）的驱动程序。

## 操作流程

### 1. 设备树节点 (已提供)
本示例所需的设备树节点已写在主仓库 [dts/imx6ull-garfield.dts](../../dts/imx6ull-garfield.dts) 中（**源文件在主仓库维护，不改内核子模块**）：

```dts
/ {
	my_led {
		compatible = "my-project,gpio-led";
		led-gpios = <&gpio1 18 GPIO_ACTIVE_HIGH>; /* GPIO1_IO18，见下方引脚说明 */
		pinctrl-names = "default";
		pinctrl-0 = <&pinctrl_my_led>;
		status = "okay";
	};
};

&iomuxc {
	pinctrl_my_led: myledgrp {
		fsl,pins = <
			MX6UL_PAD_UART1_CTS_B__GPIO1_IO18	0x1b0b0
		>;
	};
};
```

**引脚说明**：
- 这里选 `GPIO1_IO18`（pad `UART1_CTS_B`），因为它在 EVK 设备树里完全未被占用。
- **不要**用 `GPIO1_IO03`：EVK 的 `&tsc`（触摸屏）占用了 `GPIO1_IO01~04`，且 `pinctrl_tsc` 已把这四个 pad mux 成 GPIO，抢引脚会导致 LED 不亮、触摸屏异常。
- 请按自己开发板的原理图确认 LED 实际接在哪个脚，改两处即可：`led-gpios` 的 `<&gpioX N ...>`，以及 `fsl,pins` 里的 pad 宏。
- `pinctrl-0` 不能省略 —— 没有它 pad 保持复位默认功能（非 GPIO），驱动里 `of_get_named_gpio` 会取不到。

详细流程见 [README.md 4.2 节](../../README.md#42-自定义设备树-dts)。

### 2. 复制并编译设备树
```bash
cp dts/imx6ull-garfield.dts linux-fslc/arch/arm/boot/dts/nxp/imx/
cd linux-fslc
make nxp/imx/imx6ull-garfield.dtb ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
```
产物：`arch/arm/boot/dts/nxp/imx/imx6ull-garfield.dtb`。将其烧录到开发板的 `/boot` 分区并重启。

> 不用改内核 `Makefile`：`.dtb` 的生成规则是无条件模式规则，只要同名 `.dts` 存在即可编译。注意 `make dtbs` 全量编译不会带上它，需单独执行上面这条命令。

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
