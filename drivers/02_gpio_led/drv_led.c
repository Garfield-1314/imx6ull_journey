#include <linux/module.h>          // 包含内核模块的基本定义
#include <linux/kernel.h>          // 包含 printk 等内核常用函数
#include <linux/of_gpio.h>         // 包含设备树操作 GPIO 的 API
#include <linux/platform_device.h> // 包含平台设备驱动模型框架

struct my_led_data {               // 定义驱动自定义的数据结构
    int gpio;                      // 用于存储获取到的 GPIO 编号
};

static int my_led_probe(struct platform_device *pdev) // 设备与驱动匹配成功时调用的探测函数
{
    struct device *dev = &pdev->dev;                  // 获取设备结构体指针
    struct my_led_data *led_data;                    // 定义挂载数据的结构体指针
    int gpio;                                        // 定义中间变量

    // 从设备树节点（led-gpios 属性）中获取第 0 个 GPIO 编号
    gpio = of_get_named_gpio(dev->of_node, "led-gpios", 0);
    if (!gpio_is_valid(gpio)) {                       // 检查 GPIO 编号是否有效
        dev_err(dev, "Failed to get GPIO\n");         // 打印错误日志
        return -EINVAL;                               // 返回无效参数错误
    }

    // 为驱动私有数据分配内存（devm_ 开头的函数会在驱动卸载时自动释放内存）
    led_data = devm_kzalloc(dev, sizeof(*led_data), GFP_KERNEL);
    if (!led_data) return -ENOMEM;                    // 内存分配失败返回

    led_data->gpio = gpio;                            // 将获取的 GPIO 存入私有数据

    // 向内核请求并映射该 GPIO 引脚，并设置为输出模式且初始为低电平
    if (devm_gpio_request_one(dev, gpio, GPIOF_OUT_INIT_LOW, "my_led")) {
        dev_err(dev, "Failed to request GPIO\n");     // 请求失败打印错误
        return -EBUSY;                                // 返回设备忙
    }

    platform_set_drvdata(pdev, led_data);             // 将私有数据保存到平台设备中以便后期取出
    dev_info(dev, "LED GPIO %d initialized.\n", gpio); // 打印初始化成功信息
    
    // 手动将 GPIO 电平拉高，点亮 LED
    gpio_set_value(gpio, 1);

    return 0;                                         // 返回 0 表示 probe 运行成功
}

static void my_led_remove(struct platform_device *pdev) // 驱动卸载或设备移除时调用的函数
{
    struct my_led_data *led_data = platform_get_drvdata(pdev); // 从平台设备中取出 probe 时保存的私有数据
    // 在退出时将 GPIO 电平置低，熄灭 LED
    gpio_set_value(led_data->gpio, 0);
}

// 定义设备树匹配表，用于将此驱动与设备树中 compatible 属性一致的节点进行绑定
static const struct of_device_id my_led_ids[] = {
    { .compatible = "my-project,gpio-led" },           // 必须与 .dts 文件中的字符串严格匹配
    { }                                               // 结构体数组必须以空元素结尾
};
MODULE_DEVICE_TABLE(of, my_led_ids);                  // 导出匹配表，使内核能识别并加载相关模块

static struct platform_driver my_led_driver = {       // 定义平台驱动结构体
    .probe = my_led_probe,                            // 设置探测函数入口
    .remove = my_led_remove,                          // 设置移除函数入口
    .driver = {
        .name = "my_gpio_led",                         // 驱动在系统中的名称
        .of_match_table = my_led_ids,                 // 挂接设备树匹配表
    },
};

module_platform_driver(my_led_driver);                // 宏定义：自动生成模块加载和卸载的代码并注册驱动

MODULE_LICENSE("GPL");                                // 模块授权声明
MODULE_AUTHOR("Garfield");                            // 模块作者信息
MODULE_DESCRIPTION("GPIO LED Driver using Device Tree"); // 模块功能描述
