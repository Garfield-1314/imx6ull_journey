#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/of_gpio.h>
#include <linux/platform_device.h>

struct my_led_data {
    int gpio;
};

static int my_led_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    struct my_led_data *led_data;
    int gpio;

    // 从设备树中获取 gpio 属性
    gpio = of_get_named_gpio(dev->of_node, "led-gpios", 0);
    if (!gpio_is_valid(gpio)) {
        dev_err(dev, "Failed to get GPIO\n");
        return -EINVAL;
    }

    led_data = devm_kzalloc(dev, sizeof(*led_data), GFP_KERNEL);
    if (!led_data) return -ENOMEM;

    led_data->gpio = gpio;

    // 请求 GPIO 并设置为输出 (初始低电平)
    if (devm_gpio_request_one(dev, gpio, GPIOF_OUT_INIT_LOW, "my_led")) {
        dev_err(dev, "Failed to request GPIO\n");
        return -EBUSY;
    }

    platform_set_drvdata(pdev, led_data);
    dev_info(dev, "LED GPIO %d initialized.\n", gpio);
    
    // 点亮 LED
    gpio_set_value(gpio, 1);

    return 0;
}

static void my_led_remove(struct platform_device *pdev)
{
    struct my_led_data *led_data = platform_get_drvdata(pdev);
    // 熄灭 LED
    gpio_set_value(led_data->gpio, 0);
}

static const struct of_device_id my_led_ids[] = {
    { .compatible = "my-project,gpio-led" },
    { }
};
MODULE_DEVICE_TABLE(of, my_led_ids);

static struct platform_driver my_led_driver = {
    .probe = my_led_probe,
    .remove = my_led_remove,
    .driver = {
        .name = "my_gpio_led",
        .of_match_table = my_led_ids,
    },
};

module_platform_driver(my_led_driver);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Garfield");
MODULE_DESCRIPTION("GPIO LED Driver using Device Tree");
