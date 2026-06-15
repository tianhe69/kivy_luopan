@echo off
chcp 65001 >nul
echo ========================================
echo   Kivy罗盘应用打包脚本
echo ========================================
echo.

echo [1/3] 检查PyInstaller...
pip show pyinstaller >nul 2>&1
if errorlevel 1 (
    echo PyInstaller未安装，正在安装...
    pip install pyinstaller
)

echo.
echo [2/3] 开始打包...
echo 这可能需要几分钟，请耐心等待...
echo.

pyinstaller kivy_luopan.spec --clean

echo.
echo [3/3] 打包完成！
echo.
echo 生成的文件位置: dist\罗盘工具.exe
echo.
pause
