[app]

title = 罗盘工具
package.name = kivy_luopan
package.domain = org.kivy

source.dir = .
source.include_exts = py,png,jpg,kv,atlas,ttf

# 排除不需要的文件
source.exclude_dirs = __pycache__, .git, .github, build, dist, bin

version = 0.1

# 核心依赖（重要：opencv用headless版本）
requirements = python3,kivy,opencv-python-headless,Pillow,numpy

orientation = all

# Android权限
android.permissions = INTERNET,WRITE_EXTERNAL_STORAGE,READ_EXTERNAL_STORAGE

# Android配置
android.api = 33
android.minapi = 21
android.sdk = 24
android.ndk = 25b
android.ndk_api = 21

# 启动画面背景色
android.presplash_color = #000000

# 是否全屏
android.fullscreen = 0
