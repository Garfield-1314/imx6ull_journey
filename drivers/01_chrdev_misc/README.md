# 示例 1：核心杂项字符设备 (无需修改设备树)

此示例展示了如何编写一个简单的字符设备驱动，它不需要修改设备树 (Device Tree)，而是注册为一个 `miscdevice`。

## 代码结构
- `drv_misc.c`: 驱动源码。
- `Makefile`: 编译脚本。

## 操作流程

### 1. 编译
在当前目录下执行：
```bash
make
```
产物：`drv_misc.ko`

### 2. 运行与验证
将 `drv_misc.ko` 拷贝到开发板。

**在开发板上运行：**
```bash
# 加载驱动
insmod drv_misc.ko

# 验证设备节点是否生成 (misc 驱动会自动在 /dev/ 下生成节点)
ls /dev/my_misc_dev

# 读取测试
cat /dev/my_misc_dev
# 输出：Hello from kernel!

# 卸载驱动
rmmod drv_misc
```

## 核心知识点
- **Misc Device**: Linux 提供的一种接口，用于简单的字符设备，它会自动分配次设备号并创建 `/dev` 节点，无需手动执行 `mknod`。
- **No DT**: 因为它不依赖特定的硬件引脚或中断，纯粹是逻辑上的软件设备，所以无需在 `.dts` 文件中描述。
