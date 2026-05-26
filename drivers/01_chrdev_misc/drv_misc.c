#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/miscdevice.h>
#include <linux/uaccess.h>

#define DEVICE_NAME "my_misc_dev"

static ssize_t my_read(struct file *file, char __user *buf, size_t count, loff_t *ppos)
{
    char msg[] = "Hello from kernel!\n";
    size_t len = sizeof(msg);

    if (*ppos >= len) return 0;
    if (count > len - *ppos) count = len - *ppos;

    if (copy_to_user(buf, msg + *ppos, count)) return -EFAULT;

    *ppos += count;
    return count;
}

static const struct file_operations my_fops = {
    .owner = THIS_MODULE,
    .read = my_read,
};

static struct miscdevice my_misc = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = DEVICE_NAME,
    .fops = &my_fops,
};

static int __init my_init(void)
{
    return misc_register(&my_misc);
}

static void __exit my_exit(void)
{
    misc_deregister(&my_misc);
}

module_init(my_init);
module_exit(my_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Garfield");
MODULE_DESCRIPTION("Simple Misc Character Device (No DT)");
