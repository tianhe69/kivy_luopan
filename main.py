import os

# 在导入 Kivy 之前设置环境变量，避免 OpenGL 版本检查问题
os.environ['KIVY_GL_BACKEND'] = 'angle_sdl2'
os.environ['KIVY_WINDOW'] = 'sdl2'
os.environ['KIVY_AUDIO'] = 'sdl2'
os.environ['KIVY_VIDEO'] = 'sdl2'
import kivy
kivy.require('1.11.1')

# 调试信息：打印当前文件路径和执行状态
print(f"当前执行的文件: {__file__}")
print("正在初始化应用...")

from kivy.app import App
from kivy.lang import Builder
from kivy.uix.screenmanager import ScreenManager
from kivy.resources import resource_add_path
from kivy.core.text import LabelBase
from kivy.factory import Factory
from kivy.uix.spinner import SpinnerOption
import os
import sys

# 定义CustomSpinnerOption类
class CustomSpinnerOption(SpinnerOption):
    """自定义Spinner选项，支持中文显示"""
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.font_name = 'SimHei'
        self.font_size = 23

# 处理PyInstaller打包后的资源路径
if hasattr(sys, '_MEIPASS'):
    # 打包后的路径
    base_path = sys._MEIPASS
    # 添加core目录到Python路径
    sys.path.insert(0, base_path)
    resource_add_path(os.path.join(base_path, 'assets', 'fonts'))
    print(f"运行在打包环境，base_path: {base_path}")
else:
    # 开发环境路径
    base_path = os.path.dirname(__file__)
    # 添加core目录到Python路径
    sys.path.insert(0, base_path)
    resource_add_path(os.path.join(base_path, 'assets', 'fonts'))
    print(f"运行在开发环境，base_path: {base_path}")

# 直接在代码中定义KV内容，不加载外部文件
kv_content = """#:kivy 1.11.1

<MainScreen>:
    BoxLayout:
        orientation: 'vertical'
        
        # 顶部工具栏
        BoxLayout:
            size_hint_y: 0.1
            orientation: 'horizontal'
            spacing: 5
            padding: 5
            
            Button:
                text: '打开图像'
                size_hint_x: 0.14
                font_name: 'SimHei'
                on_press: root.open_file()
            
            Button:
                text: '保存图像'
                size_hint_x: 0.14
                font_name: 'SimHei'
                on_press: root.save_image()
            
            Button:
                text: '下一张'
                size_hint_x: 0.14
                font_name: 'SimHei'
                on_press: root.next_image()
            
            Button:
                text: '黑画笔'
                size_hint_x: 0.14
                font_name: 'SimHei'
                on_press: root.set_black_brush()
            
            Button:
                text: '白画笔'
                size_hint_x: 0.14
                font_name: 'SimHei'
                on_press: root.set_white_brush()
            
            Button:
                text: '上一张'
                size_hint_x: 0.14
                font_name: 'SimHei'
                on_press: root.previous_image()
            
            Button:
                text: '撤销'
                size_hint_x: 0.14
                font_name: 'SimHei'
                on_press: root.undo()
        
        # 图像显示区域
        BoxLayout:
            size_hint_y: 0.75
            padding: 10
            
            Image:
                id: image_widget
                allow_stretch: True
        
        # 底部控制栏
        BoxLayout:
            size_hint_y: 0.12
            orientation: 'horizontal'
            spacing: 3
            padding: 3
            
            # 第一列：色调分离
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: 0.25
                spacing: 2
                
                Label:
                    text: '色调分离'
                    font_size: '13sp'
                    size_hint_y: 0.15
                    font_name: 'SimHei'
                
                Slider:
                    id: threshold_lower_slider
                    min: 0
                    max: 255
                    value: 100
                    size_hint_y: 0.425
                    on_touch_up: root.on_threshold_change(threshold_lower_slider.value, threshold_upper_slider.value)
                
                Slider:
                    id: threshold_upper_slider
                    min: 0
                    max: 255
                    value: 200
                    size_hint_y: 0.425
                    on_touch_up: root.on_threshold_change(threshold_lower_slider.value, threshold_upper_slider.value)
            
            # 第二列：罗盘类型
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: 0.25
                spacing: 2
                
                Label:
                    text: '罗盘类型'
                    font_size: '13sp'
                    size_hint_y: 0.15
                    font_name: 'SimHei'
                
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: 0.2125
                    spacing: 3
                    
                    CheckBox:
                        id: compass24_checkbox
                        active: True
                        on_active: root.on_compass24_toggle(self.active)
                    
                    Label:
                        text: '24山'
                        font_size: '13sp'
                        font_name: 'SimHei'
                
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: 0.2125
                    spacing: 3
                    
                    CheckBox:
                        id: compass12_checkbox
                        active: False
                        on_active: root.on_compass12_toggle(self.active)
                    
                    Label:
                        text: '12支'
                        font_size: '13sp'
                        font_name: 'SimHei'
                
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: 0.2125
                    spacing: 3
                    
                    CheckBox:
                        id: compass28_checkbox
                        active: False
                        on_active: root.on_compass28_toggle(self.active)
                    
                    Label:
                        text: '28宿'
                        font_size: '13sp'
                        font_name: 'SimHei'
                
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: 0.2125
                    spacing: 3
                    
                    CheckBox:
                        id: xuankongda_checkbox
                        active: False
                        on_active: root.on_xuankongda_toggle(self.active)
                    
                    Label:
                        text: '玄空大卦'
                        font_size: '13sp'
                        font_name: 'SimHei'
            
            # 第三列：图形罗盘
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: 0.25
                spacing: 2
                
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: 0.85
                    spacing: 2
                    
                    CheckBox:
                        id: graphic_compass_file_checkbox
                        size_hint_x: 0.15
                        font_name: 'SimHei'
                        font_size: 13
                        on_active: root.on_graphic_compass_file_checkbox_active(args[1])
                    
                    Label:
                        text: '选择罗盘'
                        font_size: '11sp'
                        font_name: 'SimHei'
                        halign: 'left'
                        text_size: self.size
            
            # 第四列：罗盘操作
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: 0.15
                spacing: 2
                
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: 0.425
                    spacing: 2
                    
                    TextInput:
                        id: compass_scale_input
                        text: '1.0'
                        font_size: '13sp'
                        font_name: 'SimHei'
                        size_hint_x: 0.015625
                        input_filter: 'float'
                        multiline: False
                        on_text_validate: root.on_compass_scale_validate
                    
                    Button:
                        text: '变倍'
                        font_size: '11sp'
                        font_name: 'SimHei'
                        size_hint_x: 0.03
                        on_release: root.on_compass_scale_apply
                
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: 0.425
                    spacing: 2
                    
                    Label:
                        text: '旋转角度'
                        font_size: '13sp'
                        size_hint_x: 0.2
                        font_name: 'SimHei'
                        halign: 'left'
                        text_size: self.size
                    
                    TextInput:
                        id: rotation_input
                        text: '0'
                        font_size: '13sp'
                        font_name: 'SimHei'
                        size_hint_x: 0.2
                        input_filter: 'int'
                        multiline: False
                        on_text_validate: root.on_rotation_change(self.text)
                        on_focus: root.on_rotation_focus(*args)
            
            # 第五列：图像阈值
            BoxLayout:
                orientation: 'vertical'
                size_hint_x: 0.10
                spacing: 2
                
                Label:
                    text: '图像阈值'
                    font_size: '13sp'
                    size_hint_y: 0.15
                    font_name: 'SimHei'
                
                BoxLayout:
                    orientation: 'horizontal'
                    size_hint_y: 0.425
                    spacing: 2
                    
                    Label:
                        text: '阈值:'
                        font_size: '13sp'
                        size_hint_x: 0.3
                        font_name: 'SimHei'
                        halign: 'left'
                        text_size: self.size
                    
                    TextInput:
                        id: threshold_size_input
                        text: '1380'
                        font_size: '13sp'
                        font_name: 'SimHei'
                        size_hint_x: 0.5
                        input_filter: 'int'
                        multiline: False
                        on_text_validate: root.on_threshold_size_validate(self.text)
                
                Button:
                    text: '应用阈值'
                    font_size: '11sp'
                    font_name: 'SimHei'
                    size_hint_y: 0.425
                    on_release: root.on_threshold_size_apply()
"""

# 使用Builder.load_string加载KV内容，不使用load_file
print("正在加载KV内容...")
Builder.load_string(kv_content)
print("KV内容加载完成")

# 改进的字体注册逻辑
# 首先尝试从Windows字体目录加载（最可靠）
win_font_path = 'C:\\Windows\\Fonts\\simhei.ttf'
try:
    if os.path.exists(win_font_path):
        LabelBase.register(name='SimHei', fn_regular=win_font_path)
        print(f"成功从Windows字体目录注册SimHei字体: {win_font_path}")
    else:
        # 然后尝试从assets/fonts目录加载
        simhei_path = os.path.join(base_path, 'assets', 'fonts', 'simhei.ttf')
        if os.path.exists(simhei_path):
            LabelBase.register(name='SimHei', fn_regular=simhei_path)
            print(f"成功从assets/fonts目录注册SimHei字体: {simhei_path}")
        else:
            # 最后尝试直接使用文件名（依赖于resource_add_path）
            LabelBase.register(name='SimHei', fn_regular='simhei.ttf')
            print("成功注册SimHei字体（通过resource_add_path）")
except Exception as e:
    print(f"注册SimHei字体失败: {e}")
    import traceback
    traceback.print_exc()
    # 作为最后的备选，尝试使用其他常见中文字体
    try:
        # 尝试加载微软雅黑
        yahei_path = 'C:\\Windows\\Fonts\\msyh.ttc'
        if os.path.exists(yahei_path):
            LabelBase.register(name='SimHei', fn_regular=yahei_path)
            print(f"成功注册微软雅黑字体作为替代: {yahei_path}")
        else:
            # 尝试加载宋体
            song_path = 'C:\\Windows\\Fonts\\simsun.ttc'
            if os.path.exists(song_path):
                LabelBase.register(name='SimHei', fn_regular=song_path)
                print(f"成功注册宋体字体作为替代: {song_path}")
            else:
                print("无法注册任何中文字体，中文显示可能异常")
    except Exception as e2:
        print(f"注册替代字体失败: {e2}")
        traceback.print_exc()

# 导入MainScreen
print("正在导入MainScreen...")
from ui.screens.main_screen import MainScreen
print("MainScreen导入完成")

# 注册类
Factory.register('CustomSpinnerOption', cls=CustomSpinnerOption)
Factory.register('MainScreen', cls=MainScreen)
print("类注册完成")


class CompassApp(App):
    """罗盘应用程序"""
    
    def build(self):
        """构建应用"""
        print("正在构建应用...")
        self.title = '罗盘控制器'
        
        screen_manager = ScreenManager()
        
        main_screen = MainScreen(name='main')
        screen_manager.add_widget(main_screen)
        
        # 设置root属性
        self.root = screen_manager
        
        print("应用构建完成")
        return screen_manager
    
    def on_start(self):
        """应用启动时调用"""
        print("罗盘控制器已启动")
        
        # 显示阈值设置对话框
        self.show_threshold_dialog()
    
    def on_stop(self):
        """应用停止时调用"""
        print("罗盘控制器已关闭")
    
    def show_threshold_dialog(self):
        """显示阈值设置对话框"""
        try:
            from kivy.uix.popup import Popup
            from kivy.uix.boxlayout import BoxLayout
            from kivy.uix.label import Label
            from kivy.uix.textinput import TextInput
            from kivy.uix.button import Button
            
            # 创建对话框内容
            content = BoxLayout(orientation='vertical', spacing=10, padding=20)
            
            # 标题
            title_label = Label(text='设置图像调整阈值', font_size=20, font_name='SimHei')
            content.add_widget(title_label)
            
            default_label = Label(text='默认值: 1380', font_size=14, font_name='SimHei')
            content.add_widget(default_label)
            
            # 输入框
            threshold_input = TextInput(text='1380', font_size=18, font_name='SimHei', multiline=False)
            content.add_widget(threshold_input)
            
            # 按钮布局
            button_box = BoxLayout(orientation='horizontal', spacing=10)
            
            # 确定按钮
            def on_ok(instance):
                try:
                    # 获取输入的阈值
                    threshold = int(threshold_input.text)
                    # 传递阈值到ImageProcessor
                    main_screen = None
                    if hasattr(self.root.ids, 'main'):
                        main_screen = self.root.ids.main
                    elif hasattr(self.root, 'children') and len(self.root.children) > 0:
                        main_screen = self.root.children[0]
                    
                    if main_screen and hasattr(main_screen, 'image_processor'):
                        # 更新ImageProcessor的默认阈值
                        main_screen.image_processor.target_min_size = threshold
                        print(f"图像调整阈值设置为: {threshold}")
                    else:
                        print("无法获取main_screen或image_processor对象")
                except ValueError:
                    print("无效的阈值，使用默认值1380")
                except Exception as e:
                    print(f"处理阈值时出错: {e}")
                
                popup.dismiss()
            
            ok_button = Button(text='确定', font_size=16, font_name='SimHei')
            ok_button.bind(on_release=on_ok)
            button_box.add_widget(ok_button)
            
            # 添加取消按钮
            def on_cancel(instance):
                popup.dismiss()
            
            cancel_button = Button(text='取消', font_size=16, font_name='SimHei')
            cancel_button.bind(on_release=on_cancel)
            button_box.add_widget(cancel_button)
            
            # 添加按钮布局到内容
            content.add_widget(button_box)
            
            # 创建并显示对话框
            popup = Popup(title='图像调整设置', content=content, size_hint=(0.6, 0.4), title_font='SimHei')
            popup.open()
        except Exception as e:
            print(f"显示阈值对话框时出错: {e}")
            import traceback
            traceback.print_exc()


if __name__ == '__main__':
    print("正在启动CompassApp...")
    CompassApp().run()
    print("CompassApp已退出")
