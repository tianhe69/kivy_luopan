# -*- mode: python ; coding: utf-8 -*-
# Kivy罗盘应用打包配置
# 使用方法: pyinstaller kivy_luopan.spec

import sys
import os

block_cipher = None

# 获取项目根目录
project_root = os.path.dirname(os.path.abspath(SPEC))

a = Analysis(
    ['main.py'],
    pathex=[project_root],
    binaries=[],
    datas=[
        # 包含字体文件
        ('assets/fonts', 'assets/fonts'),
    ],
    hiddenimports=[
        # Kivy核心模块
        'kivy.core.window.window_sdl2',
        'kivy.core.text.text_layout',
        'kivy.core.image.img_sdl2',
        'kivy.graphics.opengl',
        'kivy.graphics.opengl_utils',
        'kivy.graphics.stencil_instructions',
        'kivy.graphics.fbo',
        'kivy.graphics.vertex_instructions',
        'kivy.graphics.context_instructions',
        'kivy.graphics.texture',
        'kivy.graphics.vbo',
        'kivy.graphics.shader',
        # PIL
        'PIL',
        'PIL._imagingtk',
        'PIL.Image',
        'PIL.ImageDraw',
        'PIL.ImageFont',
        # OpenCV
        'cv2',
        # NumPy
        'numpy',
        'numpy.core',
        'numpy.core._multiarray_umath',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'scipy',
        'pandas',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='罗盘工具',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,  # 隐藏控制台
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,  # 可以添加图标: icon='icon.ico'
)
