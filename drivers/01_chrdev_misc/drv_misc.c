// SPDX-License-Identifier: GPL-2.0
/*
 * 简单的杂项字符设备示例（不使用设备树）
 */

#include <linux/fs.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/uaccess.h>

#define DEVICE_NAME "my_misc_dev"

/* 字符设备的读操作回调函数 */
static ssize_t my_read(struct file *file, char __user *buf, size_t count,
		       loff_t *ppos)
{
	char msg[] = "Hello from kernel!\n";
	size_t len = sizeof(msg);

	if (*ppos >= len)
		return 0;

	if (count > len - *ppos)
		count = len - *ppos;

	/* 将内核空间的数据拷贝到用户空间缓冲区 */
	if (copy_to_user(buf, msg + *ppos, count))
		return -EFAULT;

	*ppos += count;

	return count;
}

/* 填充文件操作结构体，关联自定义的读函数 */
static const struct file_operations my_fops = {
	.owner = THIS_MODULE,
	.read = my_read,
};

/* 定义杂项设备结构体 */
static struct miscdevice my_misc = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = DEVICE_NAME,
	.fops = &my_fops,
};

/* 模块初始化入口函数 */
static int __init my_init(void)
{
	return misc_register(&my_misc);
}

/* 模块卸载/退出函数 */
static void __exit my_exit(void)
{
	misc_deregister(&my_misc);
}

module_init(my_init);
module_exit(my_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Garfield");
MODULE_DESCRIPTION("Simple Misc Character Device (No DT)");
