# 罗盘控制器 (Python + Kivy)

基于Python和Kivy框架开发的跨平台罗盘控制器应用，支持Windows和Android平台。

## 项目结构

```
centroid_ctrl/
├── main.py                 # Kivy应用入口
├── requirements.txt        # 依赖包列表
├── buildozer.spec         # Android打包配置
├── ui/                     # Kivy UI层
│   ├── main.kv            # 主界面KV语言文件
│   ├── screens/           # 界面屏幕
│   │   └── main_screen.py  # 主屏幕
│   └── widgets/           # 自定义控件
├── core/                   # 核心逻辑层
│   ├── compass_manager.py  # 罗盘管理器
│   └── image_processor.py  # 图像处理器
├── compass/                # 罗盘模块
│   ├── base.py            # 罗盘基类
│   ├── compass12.py       # 12支罗盘
│   └── compass24.py       # 24山罗盘
├── utils/                 # 工具函数
└── assets/                # 资源文件
    ├── fonts/             # 字体文件
    ├── icons/             # 图标文件
    └── images/            # 默认图片
```

## 功能特性

- ✅ 跨平台支持（Windows、Android）
- ✅ 图像加载和显示
- ✅ 色调分离功能
- ✅ 多种罗盘类型（24山、12支）
- ✅ 罗盘旋转角度调整
- ✅ 图像保存功能
- ✅ 下一张图像切换
- ✅ 易于扩展的罗盘架构

## 安装依赖

```bash
pip install -r requirements.txt
```

## 运行应用

### Windows平台

```bash
python main.py
```

### Android平台

1. 安装Buildozer：
```bash
pip install buildozer
```

2. 打包APK：
```bash
buildozer android debug
```

3. 安装APK到设备

## 扩展新的罗盘类型

1. 在 `compass/` 目录下创建新的罗盘类，继承 `CompassBase`
2. 在 `core/compass_manager.py` 中注册新的罗盘类型
3. 在 `ui/main.kv` 中添加新的选项

示例：

```python
# compass/compass28.py
from .base import CompassBase

class Compass28(CompassBase):
    def __init__(self, rotation_angle=0):
        super().__init__(rotation_angle)
        self.sector_angle = 12.86
        self.initial_offset = 270
        self.labels = ['角', '亢', '氐', '房', '心', '尾', '箕', '斗', '牛', '女', '虚', '危', '室', '壁', '奎', '娄', '胃', '昴', '毕', '觜', '参', '井', '鬼', '柳', '星', '张', '翼', '轸']
        self.num_sectors = 28
    
    def get_sector_angle(self):
        return self.sector_angle
    
    def get_initial_offset(self):
        return self.initial_offset
    
    def get_labels(self):
        return self.labels
    
    def get_num_sectors(self):
        return self.num_sectors
```

## 技术栈

- **UI框架**: Kivy 2.1.0
- **图像处理**: OpenCV 4.8.1.78
- **数值计算**: NumPy 1.24.3
- **打包工具**: PyInstaller, Buildozer

## 许可证

MIT License