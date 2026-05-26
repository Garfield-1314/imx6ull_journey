#include <linux/module.h>     // 包含内核模块的基本定义
#include <linux/kernel.h>     // 包含 printk 等内核常用函数
#include <linux/fs.h>         // 包含文件操作相关的结构体和函数定义
#include <linux/miscdevice.h> // 包含杂项字符设备（miscdevice）的定义
#include <linux/uaccess.h>    // 包含 copy_to_user 等用户空间数据交换函数

#define DEVICE_NAME "my_misc_dev" // 定义生成的设备节点名称

// 字符设备的读操作回调函数
static ssize_t my_read(struct file *file, char __user *buf, size_t count, loff_t *ppos)
{
    char msg[] = "Hello from kernel!\n"; // 要发送给用户空间的数据
    size_t len = sizeof(msg);            // 数据总长度

    if (*ppos >= len) return 0;           // 如果偏移量超过长度，表示读取完毕，返回 0
    if (count > len - *ppos) count = len - *ppos; // 如果用户请求的长度超过剩余长度，则只读取剩余部分

    // 将内核空间的数据拷贝到用户空间缓冲区
    if (copy_to_user(buf, msg + *ppos, count)) return -EFAULT;

    *ppos += count;                      // 更新当前读取的偏移位置
    return count;                        // 返回实际读取到的字节数
}

// 填充文件操作结构体，关联自定义的读函数
static const struct file_operations my_fops = {
    .owner = THIS_MODULE,                // 指向当前模块，防止运行时被卸载
    .read = my_read,                     // 映射读操作到 my_read
};

// 定义杂项设备结构体
static struct miscdevice my_misc = {
    .minor = MISC_DYNAMIC_MINOR,         // 动态分配次设备号
    .name = DEVICE_NAME,                 // 设备名称（会在 /dev 下创建同名节点）
    .fops = &my_fops,                    // 设置文件操作集合
};

// 模块初始化入口函数
static int __init my_init(void)
{
    // 向内核注册杂项设备
    return misc_register(&my_misc);
}

// 模块卸载/退出函数
static void __exit my_exit(void)
{
    // 从内核注销杂项设备
    misc_deregister(&my_misc);
}

module_init(my_init);                    // 声明初始化函数
module_exit(my_exit);                    // 声明退出函数

MODULE_LICENSE("GPL");                   // 声明开源协议
MODULE_AUTHOR("Garfield");               // 声明作者
MODULE_DESCRIPTION("Simple Misc Character Device (No DT)"); // 描述模块功能
