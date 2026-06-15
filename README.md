# Kivy罗盘应用

一个基于Kivy框架开发的风水罗盘图像处理工具，支持在图像上叠加多种罗盘（24山、12地支、28宿、玄空大卦），并进行图像处理和分析。

## 功能特性

- 图像加载与处理（自动裁剪空白、尺寸调整）
- 多种罗盘叠加显示（24山、12地支、28宿、玄空大卦）
- 周天度数环显示
- 图形罗盘导入与叠加
- 罗盘旋转与缩放
- 色调分离处理
- 黑白画笔绘制
- 支持中文路径/文件名

## 文件结构

```
kivy_luopan/
├── main.py                    # 应用入口
│                              # - Kivy环境配置
│                              # - 字体注册
│                              # - 应用启动逻辑
│
├── assets/                    # 资源目录
│   └── fonts/
│       └── simhei.ttf         # 黑体中文字体
│
├── core/                      # 核心业务逻辑
│   ├── __init__.py
│   ├── image_processor.py     # 图像处理器
│   │                          # - 图像加载/保存（支持中文路径）
│   │                          # - 图像裁剪/缩放
│   │                          # - 罗盘绘制
│   │                          # - 周天环绘制
│   │
│   ├── compass_manager.py     # 旧版罗盘管理器（兼容保留）
│   │
│   └── compass/               # 罗盘子模块
│       ├── __init__.py
│       ├── base.py            # 罗盘基类
│       ├── compass12.py       # 12地支罗盘
│       ├── compass24.py       # 24山罗盘（默认）
│       ├── luopan28.py        # 28宿罗盘
│       ├── compass_xuankongda.py  # 玄空大卦罗盘
│       └── compass_manager.py # 罗盘管理器（统一管理）
│
├── ui/                        # 用户界面
│   ├── __init__.py
│   ├── screens/
│   │   ├── __init__.py
│   │   └── main_screen.py     # 主屏幕
│   │                          # - 文件操作（打开/保存）
│   │                          # - 罗盘控制
│   │                          # - 画笔工具
│   │                          # - 图像显示
│   │
│   └── widgets/
│       └── __init__.py        # 自定义控件（预留）
│
└── README.md                  # 项目说明文档
```

## 技术栈

### 核心框架

| 库名称 | 类型 | 用途 |
|--------|------|------|
| **Kivy** | GUI框架 | 跨平台图形用户界面开发，支持Windows/Linux/macOS/Android/iOS |
| **OpenCV** | 计算机视觉库 | 图像处理（加载、保存、裁剪、缩放、轮廓检测、颜色转换） |
| **Pillow (PIL)** | 图像处理库 | 中文文字绘制（OpenCV不支持中文文字渲染） |
| **NumPy** | 数值计算库 | 图像数据数组操作，数学计算 |

### 库分类说明

**Kivy** - 跨平台GUI框架
- 用于构建跨平台的图形用户界面
- 支持触摸屏操作
- 使用KV语言描述界面布局
- 适合开发移动端应用

**OpenCV (cv2)** - 计算机视觉库
- 图像读取、保存、格式转换
- 图像处理（裁剪、缩放、滤波）
- 轮廓检测与形状分析
- 颜色空间转换（BGR/RGB/HSV）

**Pillow (PIL)** - Python图像处理库
- 中文字体渲染（OpenCV不支持中文）
- 图像绘制（文字、形状）
- 图像格式转换

**NumPy** - 科学计算基础库
- 多维数组操作
- 图像数据存储与处理
- 数学函数计算

## 环境要求

### Python版本
- Python 3.8+ （推荐 Python 3.9 或 3.10）

### 操作系统
- Windows 10/11（主要支持）
- Linux（理论上支持）
- macOS（理论上支持）

## 安装依赖

```bash
pip install kivy opencv-python pillow numpy
```

或使用requirements.txt：

```bash
pip install -r requirements.txt
```

### 依赖版本建议

```
kivy>=2.0.0
opencv-python>=4.5.0
Pillow>=8.0.0
numpy>=1.20.0
```

## 运行应用

```bash
python main.py
```

## 使用说明

### 基本操作

1. **打开图像**：点击"打开图像"按钮，选择要处理的图片
2. **保存图像**：点击"保存图像"按钮，保存处理后的图片（自动在文件名前加"luopan_"）
3. **上一张/下一张**：浏览同目录下的其他图片

### 罗盘设置

- **24山**：显示二十四山罗盘（默认开启）
- **12支**：显示十二地支罗盘
- **28宿**：显示二十八宿罗盘
- **玄空大卦**：显示玄空大卦罗盘

### 罗盘操作

- **旋转角度**：输入角度值，旋转罗盘
- **变倍**：输入缩放因子，调整罗盘大小
- **选择罗盘**：导入外部罗盘图片叠加显示

### 图像处理

- **色调分离**：调整上下阈值，进行色调分离处理
- **图像阈值**：设置图像调整的最小尺寸阈值
- **黑画笔/白画笔**：在图像上绘制黑色或白色线条

## 开发说明

### 中文路径支持

本项目使用 `cv2.imencode` + `np.tofile` 方式保存图像，解决OpenCV不支持中文路径的问题：

```python
def save_image(self, save_path, img=None):
    ext = os.path.splitext(save_path)[1]
    retval, im_buf_arr = cv2.imencode(ext, img)
    im_buf_arr.tofile(save_path)
```

### 字体配置

应用启动时会自动注册中文字体：
1. 优先从 `C:\Windows\Fonts\simhei.ttf` 加载
2. 其次从 `assets/fonts/simhei.ttf` 加载
3. 最后尝试微软雅黑或宋体

### 扩展罗盘

在 `core/compass/` 目录下创建新的罗盘类，继承 `base.py` 中的基类：

```python
from .base import CompassBase

class MyCompass(CompassBase):
    def __init__(self):
        super().__init__(num_sectors=8, labels=['东', '南', '西', '北', ...])
```

## 打包发布

### 方式一：一键打包（推荐）

双击运行 `build_exe.bat`，自动完成打包。

### 方式二：命令行打包

```bash
# 安装PyInstaller
pip install pyinstaller

# 使用spec配置文件打包
pyinstaller kivy_luopan.spec --clean

# 或使用简单命令
pyinstaller --onefile --windowed --add-data "assets;assets" main.py
```

### 打包输出

生成的exe文件位于 `dist/罗盘工具.exe`

### 注意事项

1. **首次打包较慢**：PyInstaller需要分析所有依赖，可能需要5-10分钟
2. **杀毒软件误报**：部分杀毒软件可能将打包的exe误报为病毒，需添加信任
3. **文件体积**：打包后的exe约100-200MB（包含Python运行时和所有依赖）
4. **跨平台**：需要在目标平台上打包（Windows exe需在Windows上打包）

### 分发给其他用户

打包后的exe文件是**独立可执行文件**，无需安装Python即可运行，适合分发给没有编程基础的用户。

## 许可证

本项目仅供学习和研究使用。

## 作者

风水罗盘图像处理工具开发团队
