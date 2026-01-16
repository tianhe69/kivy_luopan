from kivy.uix.screenmanager import Screen
from kivy.properties import ObjectProperty, StringProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.image import Image
from kivy.graphics import Color, Line, Rectangle
from kivy.core.text import Label as CoreLabel
from core.image_processor import ImageProcessor
import cv2
import numpy as np
import os
import sys

# 复制core.py中的函数到main_screen.py中
def calculate_centroid(pts):
    """对多边形区域进行质心计算
    
    Args:
        pts: 多边形顶点数组，形状为 (N, 2)
        
    Returns:
        tuple: 质心坐标 (cx, cy)，如果计算失败返回 None
    """
    cnt = pts.astype(np.float32).reshape((-1, 1, 2))
    M = cv2.moments(cnt)
    if M['m00'] != 0:
        cx = int(M['m10'] / M['m00'])
        cy = int(M['m01'] / M['m00'])
        return (cx, cy)
    return None


def is_black_background(img):
    """检测图像是否为黑底图像
    
    Args:
        img: RGB图像数组
        
    Returns:
        bool: 如果是黑底图像返回 True，否则返回 False
    """
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    mean_brightness = np.mean(gray)
    black_pixels = np.sum(gray < 50)
    total_pixels = gray.shape[0] * gray.shape[1]
    black_ratio = black_pixels / total_pixels
    edges = cv2.Canny(gray, 100, 200)
    edge_density = np.sum(edges > 0) / total_pixels
    return mean_brightness < 80 and black_ratio > 0.6 and edge_density > 0.001


def apply_threshold_separation(img, lower, upper):
    """实现色调分离预处理方法，适应黑底和白底图像
    
    Args:
        img: RGB图像数组
        lower: 色调分离下界
        upper: 色调分离上界
        
    Returns:
        mask: 处理后的二值掩码
    """
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    
    mask = np.zeros_like(gray, dtype=np.uint8)
    
    is_black_bg = is_black_background(img)
    
    if is_black_bg:
        base_mask = cv2.inRange(gray, lower, 255)
    else:
        base_mask = cv2.inRange(gray, lower, upper)
    
    black_mask = np.all(img < 50, axis=2).astype(np.uint8) * 255
    white_mask = np.all(img > 200, axis=2).astype(np.uint8) * 255
    
    if is_black_bg:
        mask = cv2.bitwise_or(base_mask, white_mask)
    else:
        mask = cv2.bitwise_or(base_mask, black_mask)
    
    kernel = np.ones((2, 2), np.uint8)
    mask = cv2.dilate(mask, kernel, iterations=1)
    mask = cv2.erode(mask, kernel, iterations=1)
    
    return mask


class MainScreen(Screen):
    """主屏幕"""
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.image_processor = ImageProcessor()
        self.current_image_path = None
        self.image_texture = None
        self.compass_lines = []
        self.compass_labels = []
        
        # 画笔相关变量
        self.is_drawing = False
        self.last_x, self.last_y = -1, -1
        self.brush_color = (0, 0, 0)
        self.brush_size = 10
        self.drawing_mode = False
        self.history = []
        self.max_history = 20
        
        # 图形罗盘相关变量
        self.graphic_compass_enabled = False
        self.graphic_compass_image = None
        self.graphic_compass_position = (0, 0)
        self.graphic_compass_rotation = 0
        self.is_dragging_compass = False
        self.compass_drag_offset = (0, 0)
        
        # 罗盘缩放因子
        self.compass_scale_factor = 1.0
        
        # 罗盘列表（存储用户选择过的罗盘）
        self.compass_list = ['无']
        self.compass_path_map = {}
    
    def on_enter(self, *args):
        """进入屏幕时调用"""
        # 初始化罗盘类型：默认显示24山
        self.image_processor.set_compass_type('24山')
        
        # 初始化图形罗盘复选框
        if 'graphic_compass_file_checkbox' in self.ids:
            self.ids.graphic_compass_file_checkbox.active = False
    
    def open_file(self):
        """打开文件"""
        print("open_file方法被调用")
        try:
            # 使用FileChooserIconView，对中文支持更好
            from kivy.uix.filechooser import FileChooserIconView
            from kivy.uix.popup import Popup
            from kivy.uix.boxlayout import BoxLayout
            from kivy.uix.button import Button
            import os
            
            # 创建文件选择器
            filechooser = FileChooserIconView()
            # 设置字体支持中文
            filechooser.font_name = 'SimHei'
            # 设置字体大小
            filechooser.font_size = 14
            # 设置文件过滤器
            filechooser.filters = ['*.png', '*.jpg', '*.jpeg', '*.bmp']
            
            # 确保FileChooser使用正确的编码处理中文
            filechooser.encoding = 'utf-8'
            
            # 记住上次访问的目录
            if hasattr(self, 'last_visited_dir') and os.path.exists(self.last_visited_dir):
                filechooser.path = self.last_visited_dir
                print(f"使用上次访问的目录: {self.last_visited_dir}")
            else:
                # 默认使用图片文件夹
                pictures_path = os.path.expanduser('~/Pictures')
                if os.path.exists(pictures_path):
                    filechooser.path = pictures_path
                    print(f"使用默认图片文件夹: {pictures_path}")
                else:
                    # 尝试使用桌面文件夹
                    desktop_path = os.path.expanduser('~/Desktop')
                    if os.path.exists(desktop_path):
                        filechooser.path = desktop_path
                        print(f"使用桌面文件夹: {desktop_path}")
                    else:
                        # 作为最后的备选，使用当前目录
                        filechooser.path = os.getcwd()
                        print(f"使用当前目录: {os.getcwd()}")
            
            # 创建布局
            layout = BoxLayout(orientation='vertical')
            layout.add_widget(filechooser)
            
            # 创建选择按钮
            select_btn = Button(text='选择', size_hint_y=0.1, font_name='SimHei')
            layout.add_widget(select_btn)
            
            # 创建弹窗
            popup = Popup(title='选择图像', content=layout, size_hint=(0.8, 0.8), title_font='SimHei')
            
            # 按钮事件处理
            def on_select(instance):
                if filechooser.selection:
                    # 记住当前选择的目录
                    self.last_visited_dir = os.path.dirname(filechooser.selection[0])
                    print(f"记住当前目录: {self.last_visited_dir}")
                    self._file_selected(filechooser.selection)
                popup.dismiss()
            
            select_btn.bind(on_release=on_select)
            
            # 显示弹窗
            popup.open()
            
        except Exception as e:
            print(f"open_file方法出错: {e}")
            import traceback
            traceback.print_exc()
            # 显示简单的错误信息
            from kivy.uix.label import Label
            from kivy.uix.popup import Popup
            error_label = Label(text=f"打开文件失败: {str(e)}", font_name='SimHei')
            error_popup = Popup(title='错误', content=error_label, size_hint=(0.6, 0.4), title_font='SimHei')
            error_popup.open()
    
    def _file_selection_callback(self, selection):
        """文件选择回调（Android）"""
        if selection:
            self._file_selected(selection)
    
    def _file_selected(self, selection):
        """文件选择处理"""
        print(f"文件选择: {selection}")
        try:
            if selection:
                self.current_image_path = selection[0] if isinstance(selection, list) else selection
                print(f"选择的文件路径: {self.current_image_path}")
                
                # 重置罗盘倍数到1.0
                self.compass_scale_factor = 1.0
                if 'compass_scale_input' in self.ids:
                    self.ids.compass_scale_input.text = '1.0'
                    print("重置罗盘倍数到1.0")
                
                if self.image_processor.load_image(self.current_image_path):
                    print("图像加载成功")
                    
                    # 调用新的图像处理功能
                    processed_img = self.image_processor.process_image(self.image_processor.original_image)
                    self.image_processor.processed_image = processed_img
                    
                    self.update_image_display()
                else:
                    print("图像加载失败")
        except Exception as e:
            print(f"_file_selected方法出错: {e}")
            import traceback
            traceback.print_exc()
    
    def save_image(self):
        """保存图像"""
        if not self.current_image_path or self.image_processor.processed_image is None:
            print("没有图像可保存")
            return
        
        import os
        import time
        
        try:
            abs_path = os.path.abspath(self.current_image_path)
            dir_path = os.path.dirname(abs_path)
            
            if not os.path.exists(dir_path):
                os.makedirs(dir_path, exist_ok=True)
            
            # 获取原始文件名和扩展名
            base_name = os.path.basename(abs_path)
            name_without_ext, ext = os.path.splitext(base_name)
            # 在文件名前加luopan_，保持扩展名不变
            save_path = os.path.join(dir_path, f"luopan_{name_without_ext}{ext}")
            
            # 保存包含所有绘制元素的图像（罗盘、形心、轮廓线等）
            if hasattr(self, 'displayed_image') and self.displayed_image is not None:
                # displayed_image是BGR格式，cv2.imwrite直接保存BGR格式
                cv2.imwrite(save_path, self.displayed_image)
                print(f"图像已保存到: {save_path}")
            elif self.image_processor.processed_image is not None:
                # 如果没有displayed_image，使用processed_image作为备选
                cv2.imwrite(save_path, self.image_processor.processed_image)
                print(f"图像已保存到: {save_path}")
                
                from kivy.uix.popup import Popup
                from kivy.uix.label import Label
                from kivy.uix.button import Button
                from kivy.uix.boxlayout import BoxLayout
                
                content = BoxLayout(orientation='vertical', spacing=10, padding=10)
                label = Label(text=f'图像已保存到:\n{save_path}', font_name='SimHei', size_hint_y=0.7)
                btn = Button(text='确定', font_name='SimHei', size_hint_y=0.3)
                content.add_widget(label)
                content.add_widget(btn)
                
                popup = Popup(title='保存成功', content=content, size_hint=(0.8, 0.4), title_font='SimHei')
                popup.open()
                
                def close_popup(instance):
                    popup.dismiss()
                
                btn.bind(on_press=close_popup)
            else:
                print("没有处理过的图像可保存")
        except Exception as e:
            print(f"保存图像时出错: {e}")
            import traceback
            traceback.print_exc()
    
    def previous_image(self):
        """上一张图像"""
        if not self.current_image_path:
            return
        
        import os
        dir_path = os.path.dirname(self.current_image_path)
        base_name = os.path.basename(self.current_image_path)
        
        files = [f for f in os.listdir(dir_path)
                 if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
        files.sort()
        
        try:
            current_index = files.index(base_name)
            if current_index > 0:
                previous_file = files[current_index - 1]
                previous_path = os.path.join(dir_path, previous_file)
                if self.image_processor.load_image(previous_path):
                    self.current_image_path = previous_path
                    
                    # 调用图像处理功能
                    processed_img = self.image_processor.process_image(self.image_processor.processed_image)
                    self.image_processor.processed_image = processed_img
                    
                    self.update_image_display()
        except ValueError:
            pass
    
    def next_image(self):
        """下一张图像"""
        if not self.current_image_path:
            return
        
        import os
        dir_path = os.path.dirname(self.current_image_path)
        base_name = os.path.basename(self.current_image_path)
        
        files = [f for f in os.listdir(dir_path)
                 if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
        files.sort()
        
        try:
            current_index = files.index(base_name)
            if current_index < len(files) - 1:
                next_file = files[current_index + 1]
                next_path = os.path.join(dir_path, next_file)
                if self.image_processor.load_image(next_path):
                    self.current_image_path = next_path
                    
                    # 调用图像处理功能
                    processed_img = self.image_processor.process_image(self.image_processor.processed_image)
                    self.image_processor.processed_image = processed_img
                    
                    self.update_image_display()
        except ValueError:
            pass
    
    def on_threshold_change(self, lower, upper):
        """色调分离滑块变化"""
        print(f"色调分离: lower={lower}, upper={upper}")
        self.image_processor.threshold_lower = int(lower)
        self.image_processor.threshold_upper = int(upper)
        self.update_image_display()
    
    def on_compass24_toggle(self, active):
        """24山罗盘切换"""
        print(f"24山罗盘切换: {active}")
        if active:
            # 取消12地支罗盘
            if 'compass12_checkbox' in self.ids:
                self.ids.compass12_checkbox.active = False
            # 设置24山罗盘
            self.image_processor.set_compass_type('24山')
        else:
            # 取消24山罗盘，设置为None
            self.image_processor.set_compass_type(None)
        self.update_image_display()
    
    def on_compass12_toggle(self, active):
        """12地支罗盘切换"""
        print(f"12地支罗盘切换: {active}")
        if active:
            # 取消24山罗盘
            if 'compass24_checkbox' in self.ids:
                self.ids.compass24_checkbox.active = False
            # 设置12地支罗盘
            self.image_processor.set_compass_type('12支')
        else:
            # 取消12地支罗盘，设置为None
            self.image_processor.set_compass_type(None)
        self.update_image_display()
    
    def on_compass28_toggle(self, active):
        """28宿罗盘切换"""
        print(f"28宿罗盘切换: {active}")
        self.image_processor.compass_manager.show_compass28 = active
        self.update_image_display()
    
    def on_xuankongda_toggle(self, active):
        """玄空大卦罗盘切换"""
        print(f"玄空大卦罗盘切换: {active}")
        self.image_processor.compass_manager.show_xuankongda = active
        self.update_image_display()
    
    def on_rotation_change(self, text_input):
        """旋转角度变化"""
        print(f"on_rotation_change被调用，输入: {text_input}")
        try:
            angle = float(text_input)
            print(f"旋转角度: {angle}")
            self.image_processor.set_rotation_angle(angle)
            self.graphic_compass_rotation = angle
            print(f"图形罗盘旋转角度: {self.graphic_compass_rotation}")
            # 即使processed_image为None，也要更新图形罗盘的旋转角度
            self.update_image_display()
        except ValueError:
            print(f"旋转角度输入错误: {text_input}")
            pass
    
    def on_rotation_focus(self, instance, value):
        """旋转角度焦点变化"""
        if not value:
            # 当失去焦点时，更新旋转角度
            try:
                angle = float(instance.text)
                print(f"旋转角度（失去焦点）: {angle}")
                self.image_processor.set_rotation_angle(angle)
                self.graphic_compass_rotation = angle
                self.update_image_display()
            except ValueError:
                print(f"旋转角度输入错误: {instance.text}")
                pass
    
    def on_threshold_size_validate(self, text):
        """验证并应用阈值输入"""
        try:
            threshold = int(text)
            print(f"图像阈值验证: {threshold}")
            # 更新ImageProcessor的阈值
            self.image_processor.target_min_size = threshold
            # 重新处理当前图像
            if self.image_processor.original_image is not None:
                processed_img = self.image_processor.process_image(self.image_processor.original_image)
                self.image_processor.processed_image = processed_img
                self.update_image_display()
            print(f"图像阈值已更新为: {threshold}")
        except ValueError:
            print(f"图像阈值输入错误: {text}")
            pass
    
    def on_threshold_size_apply(self):
        """应用阈值按钮点击"""
        try:
            threshold = int(self.ids.threshold_size_input.text)
            print(f"应用图像阈值: {threshold}")
            # 更新ImageProcessor的阈值
            self.image_processor.target_min_size = threshold
            # 重新处理当前图像
            if self.image_processor.original_image is not None:
                processed_img = self.image_processor.process_image(self.image_processor.original_image)
                self.image_processor.processed_image = processed_img
                self.update_image_display()
            print(f"图像阈值已应用: {threshold}")
        except ValueError:
            print(f"图像阈值输入错误: {self.ids.threshold_size_input.text}")
            pass
    
    def on_compass_zoom_in(self):
        """罗盘放大"""
        print("罗盘放大")
        self.compass_scale_factor *= 1.1
        print(f"当前缩放因子: {self.compass_scale_factor:.2f}")
        self.update_image_display()
    
    def on_compass_zoom_out(self):
        """罗盘缩小"""
        print("罗盘缩小")
        self.compass_scale_factor *= 0.9
        print(f"当前缩放因子: {self.compass_scale_factor:.2f}")
        self.update_image_display()
    
    def on_compass_scale_validate(self, text_input):
        """罗盘倍数验证"""
        print(f"on_compass_scale_validate被调用，输入: {text_input}")
        try:
            scale = float(text_input)
            print(f"罗盘倍数验证: {scale}")
            if scale >= 0.01 and scale <= 100:
                self.compass_scale_factor = scale
                print(f"罗盘倍数更新: {self.compass_scale_factor}")
                self.update_image_display()
            else:
                print(f"罗盘倍数超出范围: {scale}")
        except ValueError:
            print(f"罗盘倍数输入错误: {text_input}")
            pass
    
    def on_compass_scale_focus(self, instance, value):
        """罗盘倍数焦点变化"""
        print(f"on_compass_scale_focus被调用，value: {value}")
        if not value:
            # 当失去焦点时，更新倍数
            try:
                scale = float(instance.text)
                print(f"罗盘倍数（失去焦点）: {scale}")
                if scale >= 0.01 and scale <= 100:
                    self.compass_scale_factor = scale
                    print(f"罗盘倍数更新: {self.compass_scale_factor}")
                    self.update_image_display()
                else:
                    print(f"罗盘倍数超出范围: {scale}")
            except ValueError:
                print(f"罗盘倍数输入错误: {instance.text}")
                pass
    
    def on_compass_scale_focus(self, instance, value):
        """罗盘倍数焦点变化"""
        print(f"on_compass_scale_focus被调用，value: {value}")
        if not value:
            # 当失去焦点时，更新倍数
            try:
                scale = float(instance.text)
                print(f"罗盘倍数（失去焦点）: {scale}")
                if scale >= 0.01 and scale <= 100:
                    self.compass_scale_factor = scale
                    print(f"罗盘倍数更新: {self.compass_scale_factor}")
                    self.update_image_display()
                else:
                    print(f"罗盘倍数超出范围: {scale}")
            except ValueError:
                print(f"罗盘倍数输入错误: {instance.text}")
                pass
    
    def on_compass_scale_apply(self, instance):
        """罗盘倍数应用按钮点击"""
        print(f"on_compass_scale_apply被调用，instance: {instance}")
        try:
            scale = float(self.ids['compass_scale_input'].text)
            print(f"罗盘倍数应用按钮点击: {scale}")
            if scale >= 0.01 and scale <= 100:
                self.compass_scale_factor = scale
                print(f"罗盘倍数更新: {self.compass_scale_factor}")
                self.update_image_display()
            else:
                print(f"罗盘倍数超出范围: {scale}")
        except ValueError:
            print(f"罗盘倍数输入错误: {self.ids['compass_scale_input'].text}")
            pass
    
    def on_graphic_compass_change(self, compass_name):
        """图形罗盘选择框变化（已废弃，保留兼容性）"""
        print(f"图形罗盘选择框变化: {compass_name}")
    
    def on_graphic_compass_file_checkbox_active(self, active):
        """图形罗盘选择文件复选框变化"""
        print(f"图形罗盘选择文件复选框: {active}")
        
        if active:
            # 打开文件选择对话框
            self.open_graphic_compass_file()
        else:
            # 取消选中时，不显示任何图形罗盘
            self.graphic_compass_enabled = False
            self.graphic_compass_image = None
            print("不显示图形罗盘")
            
            # 只在有图像时才更新显示
            if self.image_processor.processed_image is not None:
                self.update_image_display()
    
    def open_graphic_compass_file(self):
        """打开图形罗盘文件"""
        from kivy.uix.filechooser import FileChooserIconView
        from kivy.uix.popup import Popup
        from kivy.uix.button import Button
        
        filechooser = FileChooserIconView()
        filechooser.filters = ['*.png']
        filechooser.font_name = 'SimHei'
        filechooser.multiselect = False
        
        # 设置默认路径为用户的图片文件夹
        import os
        pictures_path = os.path.expanduser('~/Pictures')
        if os.path.exists(pictures_path):
            filechooser.path = pictures_path
        
        box = BoxLayout(orientation='vertical')
        box.add_widget(filechooser)
        
        btn = Button(text='选择', size_hint_y=0.1, font_name='SimHei')
        box.add_widget(btn)
        
        popup = Popup(title='选择罗盘图像', content=box, size_hint=(0.9, 0.9), title_font='SimHei')
        popup.open()
        
        def on_button_release(instance):
            if filechooser.selection:
                self._graphic_compass_file_selected(filechooser.selection[0])
                # 选中文件后，保持复选框的选中状态，不再次触发事件
            else:
                # 用户取消选择，不修改复选框状态，只关闭图形罗盘
                self.graphic_compass_enabled = False
                self.graphic_compass_image = None
            popup.dismiss()
        
        btn.bind(on_release=on_button_release)
    
    def _graphic_compass_file_selected(self, file_path):
        """图形罗盘文件选择处理"""
        print(f"选择的罗盘图像: {file_path}")
        try:
            # 使用numpy.fromfile和cv2.imdecode来处理中文路径
            import numpy as np
            with open(file_path, 'rb') as f:
                img_array = np.fromfile(f, np.uint8)
            compass_image = cv2.imdecode(img_array, cv2.IMREAD_UNCHANGED)
            
            if compass_image is not None:
                print(f"罗盘图像加载成功，形状: {compass_image.shape}, 数据类型: {compass_image.dtype}")
                self.graphic_compass_image = compass_image
                self.graphic_compass_position = (0, 0)
                self.graphic_compass_enabled = True
                
                # 将新选择的罗盘添加到列表
                compass_name = os.path.basename(file_path)
                if compass_name not in self.compass_list:
                    self.compass_list.append(compass_name)
                    self.compass_path_map[compass_name] = file_path
                    print(f"添加新罗盘到列表: {compass_name}")
                
                self.update_image_display()
                print("罗盘图像加载完成")
            else:
                print("罗盘图像加载失败：cv2.imdecode返回None")
        except Exception as e:
            print(f"加载罗盘图像时出错: {e}")
            import traceback
            traceback.print_exc()
    
    def set_black_brush(self):
        """切换到黑色画笔"""
        self.brush_color = (0, 0, 0)
        self.drawing_mode = True
        print("切换到黑色画笔")
    
    def set_white_brush(self):
        """切换到白色画笔"""
        self.brush_color = (255,255,255)
        self.drawing_mode = True
        print("切换到白色画笔")
    
    def end_drawing(self):
        """清空所有画笔"""
        if self.history:
            self.image_processor.processed_image = self.history[0].copy()
            self.history = []
            self.update_image_display()
            print("清空所有画笔")
        self.drawing_mode = False
        self.is_drawing = False
        self.last_x, self.last_y = -1, -1
    
    def undo(self):
        """撤销上一步操作"""
        if self.history:
            self.image_processor.processed_image = self.history.pop()
            self.update_image_display()
            self.drawing_mode = False
            print("撤销成功")
    
    def save_history(self):
        """保存当前图像状态到历史记录"""
        if self.image_processor.processed_image is not None:
            self.history.append(self.image_processor.processed_image.copy())
            if len(self.history) > self.max_history:
                self.history.pop(0)
    
    def update_image_display(self):
        """更新图像显示"""
        print(f"update_image_display被调用")
        print(f"processed_image: {self.image_processor.processed_image}")
        
        # 尝试从罗盘倍数输入框读取倍数（移到开头，确保总是读取）
        print(f"self.ids: {self.ids}")
        if 'compass_scale_input' in self.ids:
            print(f"compass_scale_input存在: {self.ids['compass_scale_input']}")
            try:
                scale = float(self.ids.compass_scale_input.text)
                print(f"从罗盘倍数输入框读取倍数: {scale}")
                if scale >= 0.01 and scale <= 100:
                    self.compass_scale_factor = scale
                    print(f"罗盘倍数更新: {self.compass_scale_factor}")
                else:
                    print(f"罗盘倍数超出范围: {scale}")
            except ValueError:
                print(f"罗盘倍数输入错误: {self.ids.compass_scale_input.text}")
                pass
        else:
            print("compass_scale_input不存在")
        
        # 如果没有处理过的图像，但有图形罗盘，创建一个空白图像用于显示图形罗盘
        if self.image_processor.processed_image is None:
            if self.graphic_compass_enabled and self.graphic_compass_image is not None:
                print("processed_image为None，但有图形罗盘，创建空白图像")
                # 创建一个1920x1080的黑色背景图像
                img = np.zeros((1080, 1920, 3), dtype=np.uint8)
                # 设置质心为图像中心
                cx, cy = 960, 540
                self.image_processor.centroid = (cx, cy)
                # 读取旋转角度
                if 'rotation_input' in self.ids:
                    try:
                        angle = float(self.ids.rotation_input.text)
                        print(f"从旋转角度输入框读取角度: {angle}")
                        self.graphic_compass_rotation = angle
                        print(f"图形罗盘旋转角度: {self.graphic_compass_rotation}")
                    except ValueError:
                        print(f"旋转角度输入错误: {self.ids.rotation_input.text}")
                        pass
                # 叠加图形罗盘
                self._overlay_graphic_compass(img)
                # 显示图像
                img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
                img_flipped = cv2.flip(img_rgb, 0)
                
                from kivy.core.image import Image as KivyImage
                from kivy.graphics.texture import Texture
                
                height, width, channels = img_flipped.shape
                print(f"图像尺寸: {width}x{height}")
                texture = Texture.create(size=(width, height), colorfmt='rgb')
                texture.blit_buffer(img_flipped.flatten(), colorfmt='rgb', bufferfmt='ubyte')
                
                print(f"ids: {self.ids}")
                if 'image_widget' in self.ids:
                    self.ids.image_widget.texture = texture
                    self.ids.image_widget.size = (width, height)
                    print("图像纹理已设置")
            return
        
        img = self.image_processor.processed_image.copy()
        print(f"图像形状: {img.shape}")
        
        # 使用原来的轮廓检测逻辑
        mask = apply_threshold_separation(img, self.image_processor.threshold_lower, self.image_processor.threshold_upper)
        
        blurred = cv2.GaussianBlur(mask, (5, 5), 0)
        
        contours, hierarchy = cv2.findContours(blurred, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_TC89_L1)
        
        if contours:
            is_black_bg = is_black_background(img)
            
            valid_contours = []
            if is_black_bg:
                min_area = 500
                min_length = 500
                for cnt in contours:
                    area = cv2.contourArea(cnt)
                    length = cv2.arcLength(cnt, True)
                    if area >= min_area or length >= min_length:
                        valid_contours.append(cnt)
            else:
                min_area = 3000
                for cnt in contours:
                    area = cv2.contourArea(cnt)
                    if area >= min_area:
                        valid_contours.append(cnt)
            
            if not valid_contours:
                valid_contours = contours
            
            max_cnt = max(valid_contours, key=cv2.contourArea)
            
            if is_black_bg:
                epsilon = 0.001 * cv2.arcLength(max_cnt, True)
            else:
                epsilon = 0.003 * cv2.arcLength(max_cnt, True)
            
            approx = cv2.approxPolyDP(max_cnt, epsilon, True)
            
            new_points = approx.reshape(-1, 2)
            
            # 计算质心
            centroid = calculate_centroid(new_points)
            if centroid:
                cx, cy = centroid
                self.image_processor.centroid = (cx, cy)
                print(f"质心计算完成: ({cx}, {cy})")
                # 绘制轮廓线
            cv2.drawContours(img, [max_cnt], -1, (0,255, 0), 5)
            # 绘制质心点
            cv2.circle(img, (cx, cy), 8, (0, 0, 255), -1)
        
        # 绘制质心十字线（始终显示）
        if self.image_processor.centroid:
            cx, cy = self.image_processor.centroid
            img_height, img_width = img.shape[:2]
            # 绘制红色十字线
            cv2.line(img, (cx, 0), (cx, img_height-1), (0, 0, 255), 5)
            cv2.line(img, (0, cy), (img_width-1, cy), (0, 0, 255), 5)
        
        if self.image_processor.show_compass and self.image_processor.centroid:
            self._draw_compass_on_image(img)
        
        # 绘制28宿罗盘（独立显示，不依赖其他罗盘）
        if self.image_processor.compass_manager.show_compass28 and self.image_processor.centroid:
            cx, cy = self.image_processor.centroid
            img_height, img_width = img.shape[:2]
            # 使用与周天度数环相同的max_radius值
            max_radius = min(cx, cy, img_width - cx, img_height - cy)
            self._draw_compass28_on_image(img, cx, cy, max_radius)
        
        # 绘制周天环（最外层，始终显示）
        if self.image_processor.centroid:
            cx, cy = self.image_processor.centroid
            img_height, img_width = img.shape[:2]
            
            # 周天度数盘半径达到图片最大范围
            max_radius = min(cx, cy, img_width - cx, img_height - cy)
            self._draw_zhoutian_ring_on_image(img, cx, cy, max_radius)
        
        # 叠加图形罗盘
        if self.graphic_compass_enabled and self.graphic_compass_image is not None:
            self._overlay_graphic_compass(img)
        
        # 保存当前显示的图像（包含所有绘制元素）
        self.displayed_image = img.copy()
        
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        img_flipped = cv2.flip(img_rgb, 0)
        
        from kivy.core.image import Image as KivyImage
        from kivy.graphics.texture import Texture
        
        height, width, channels = img_flipped.shape
        print(f"图像尺寸: {width}x{height}")
        texture = Texture.create(size=(width, height), colorfmt='rgb')
        texture.blit_buffer(img_flipped.flatten(), colorfmt='rgb', bufferfmt='ubyte')
        
        print(f"ids: {self.ids}")
        if 'image_widget' in self.ids:
            self.ids.image_widget.texture = texture
            self.ids.image_widget.size = (width, height)
            print("图像纹理已设置")
    
    def _draw_compass_on_image(self, img):
        """在图像上绘制罗盘"""
        if not self.image_processor.centroid:
            return
        
        cx, cy = self.image_processor.centroid
        img_height, img_width = img.shape[:2]
        line_length = min(img_width, img_height) * 0.6 * 0.75
        
        # 使用与周天度数环相同的max_radius值
        max_radius = min(cx, cy, img_width - cx, img_height - cy)
        
        lines, texts = self.image_processor.draw_compass(
            (cx, cy), line_length, max_radius, img_width, img_height,
            line_color=(255, 140, 0), text_color=(128, 0, 128),
            linewidth=2.5, fontsize=16
        )
        
        for start, end in lines:
            start = (int(start[0]), int(start[1]))
            end = (int(end[0]), int(end[1]))
            cv2.line(img, start, end, (255, 140, 0), 5)
        
        # 绘制玄空大卦罗盘（附加罗盘）
        if self.image_processor.compass_manager.show_xuankongda:
            # 使用与周天度数环相同的max_radius值
            max_radius = min(cx, cy, img_width - cx, img_height - cy)
            lines_xuankongda, texts_xuankongda, inner_radius_xuankongda, outer_radius_xuankongda = self.image_processor.draw_xuankongda(
                (cx, cy), max_radius,
                line_color=(0, 165, 255), text_color=(0, 0, 255),
                linewidth=2.5, fontsize=14
            )
            
            # 绘制玄空大卦分隔线和刻度线
            for line in lines_xuankongda:
                if len(line) == 2:
                    # 普通分隔线
                    start, end = line
                    thickness = 5
                    color = (0, 191, 255)  # 亮蓝色 (BGR)
                elif len(line) == 3:
                    # 检查第三个元素的类型，判断是颜色还是粗细
                    if isinstance(line[2], (tuple, list)):
                        # 带颜色信息的刻度线
                        start, end, line_color = line
                        thickness = 2
                        color = line_color  # 使用线自带的颜色
                    else:
                        # 带粗细信息的分隔线
                        start, end, thickness = line
                        thickness = int(thickness) * 2.5  # 应用2.5倍粗
                        color = (0, 0, 255)  # 大红色 (BGR)
                
                start = (int(start[0]), int(start[1]))
                end = (int(end[0]), int(end[1]))
                cv2.line(img, start, end, color, thickness)
            
            # 绘制玄空大卦罗盘文字（使用PIL）
            try:
                from PIL import Image as PILImage, ImageDraw, ImageFont
                
                # 创建PIL图像
                img_pil = PILImage.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
                draw = ImageDraw.Draw(img_pil)
                
                # 加载中文字体
                try:
                    font_outer = ImageFont.truetype('C:\\Windows\\Fonts\\simhei.ttf', 18)
                    font_middle = ImageFont.truetype('C:\\Windows\\Fonts\\simhei.ttf', 16)
                    font_inner = ImageFont.truetype('C:\\Windows\\Fonts\\simhei.ttf', 14)
                except:
                    font_outer = font_middle = font_inner = ImageFont.load_default()
                
                # 绘制玄空大卦罗盘文字
                # 前64个是最外圈（卦名），中间64个是中圈（卦运），最后64个是内圈（五行）
                for i, (x, y, label) in enumerate(texts_xuankongda):
                    if i < 64:
                        font = font_outer
                    elif i < 128:
                        font = font_middle
                    else:
                        font = font_inner
                    
                    # 计算文字大小
                    bbox = draw.textbbox((0, 0), label, font=font)
                    text_width = bbox[2] - bbox[0]
                    text_height = bbox[3] - bbox[1]
                    
                    # 计算圆形半径（比文字稍大）
                    radius = max(text_width, text_height) // 2 + 5
                    
                    # 绘制白色圆形背景
                    draw.ellipse((int(x)-radius, int(y)-radius, int(x)+radius, int(y)+radius), fill=(255, 255, 255))
                    
                    # 绘制文字
                    draw.text((int(x)-text_width//2, int(y)-text_height//2), label, font=font, fill=(0, 0, 255))
                
                # 将PIL图像转换回OpenCV格式
                img[:, :, :] = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)
            except Exception as e:
                print(f"绘制玄空大卦文字时出错: {e}")
                import traceback
                traceback.print_exc()
                pass
        
        # 使用PIL绘制中文文字
        try:
            from PIL import Image as PILImage, ImageDraw, ImageFont
            
            # 创建PIL图像
            img_pil = PILImage.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
            draw = ImageDraw.Draw(img_pil)
            
            # 加载中文字体
            try:
                font = ImageFont.truetype('C:\Windows\Fonts\simhei.ttf', 22)
            except:
                font = ImageFont.load_default()
            
            # 绘制文字
            for x, y, label in texts:
                try:
                    # 计算文字大小
                    bbox = draw.textbbox((0, 0), label, font=font)
                    text_width = bbox[2] - bbox[0]
                    text_height = bbox[3] - bbox[1]
                    
                    # 计算圆形半径（比文字稍大）
                    radius = max(text_width, text_height) // 2 + 5
                    
                    # 绘制白色圆形背景
                    draw.ellipse((int(x)-radius, int(y)-radius, int(x)+radius, int(y)+radius), fill=(255, 255, 255))
                    
                    # 绘制文字
                    draw.text((int(x)-text_width//2, int(y)-text_height//2), label, font=font, fill=(128, 0, 128))
                except Exception as e:
                    print(f"绘制普通罗盘文字时出错: {e}")
                    continue
            
            # 转换回OpenCV格式
            img[:, :, :] = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)
        except Exception as e:
            print(f"使用PIL绘制中文文字时出错: {e}")
            # 如果PIL不可用或出错，使用英文标签
            for x, y, label in texts:
                try:
                    # 绘制文字
                    cv2.putText(img, label, (int(x)-10, int(y)+5), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.5, (128, 0, 128), 2)
                except Exception as e2:
                    print(f"使用cv2绘制文字时出错: {e2}")
                    continue
    
    def _draw_compass28_on_image(self, img, cx, cy, text_distance):
        """在图像上绘制28宿罗盘"""
        lines, texts, inner_radius, outer_radius = self.image_processor.draw_compass28(
            (cx, cy), text_distance,
            line_color=(255, 140, 0), text_color=(128, 0, 128),
            linewidth=2.5, fontsize=16
        )
        
        compass28 = self.image_processor.compass_manager.compass28
        
        # 绘制内圆和外圆（紫色）
        cv2.circle(img, (int(cx), int(cy)), int(inner_radius), (128, 0, 128), 5)
        cv2.circle(img, (int(cx), int(cy)), int(outer_radius), (128, 0, 128), 5)
        
        # 获取旋转角度
        rotation_angle = self.image_processor.get_rotation_angle()
        
        # 根据宿度数绘制分割线（紫色，加粗一倍）
        for start_angle in compass28.start_angles:
            angle_deg = start_angle - 90 + rotation_angle
            angle_rad = np.deg2rad(angle_deg)
            x1 = cx + inner_radius * np.cos(angle_rad)
            y1 = cy + inner_radius * np.sin(angle_rad)
            x2 = cx + outer_radius * np.cos(angle_rad)
            y2 = cy + outer_radius * np.sin(angle_rad)
            cv2.line(img, (int(x1), int(y1)), (int(x2), int(y2)), (128, 0, 128), 5)
        
        # 使用PIL绘制28宿文字
        try:
            from PIL import Image as PILImage, ImageDraw, ImageFont
            
            # 创建PIL图像
            img_pil = PILImage.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
            draw = ImageDraw.Draw(img_pil)
            
            # 加载中文字体（稍小一些）
            try:
                font = ImageFont.truetype('C:\Windows\Fonts\simhei.ttf', 14)
            except:
                font = ImageFont.load_default()
            
            # 绘制文字（按照排序后的顺序）
            for x, y, label in texts:
                # 计算文字大小（字号缩小到75%）
                bbox = draw.textbbox((0, 0), label, font=font)
                text_width = bbox[2] - bbox[0]
                text_height = bbox[3] - bbox[1]
                
                # 计算圆形半径（比文字稍大）
                radius = max(text_width, text_height) // 2 + 5
                
                # 绘制白色圆形背景
                draw.ellipse((int(x)-radius, int(y)-radius, int(x)+radius, int(y)+radius), fill=(255, 255, 255))
                
                # 绘制紫色圈（字套圈）
                draw.ellipse((int(x)-radius, int(y)-radius, int(x)+radius, int(y)+radius), outline=(128, 0, 128), width=2)
                
                # 绘制紫色文字
                draw.text((int(x)-text_width//2, int(y)-text_height//2), label, font=font, fill=(128, 0, 128))
            
            # 转换回OpenCV格式
            img[:, :, :] = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)
        except Exception as e:
            print(f"使用PIL绘制28宿文字时出错: {e}")
            import traceback
            traceback.print_exc()
            pass
    
    def _overlay_graphic_compass(self, img):
        """叠加图形罗盘"""
        if self.graphic_compass_image is None:
            print("图形罗盘图像为None，跳过叠加")
            return
        
        # 读取罗盘倍数（已在update_image_display中读取，不再重复读取）
        # if 'compass_scale_input' in self.ids:
        #     try:
        #         scale = float(self.ids.compass_scale_input.text)
        #         print(f"从罗盘倍数输入框读取倍数（_overlay_graphic_compass）: {scale}")
        #         if scale >= 0.01 and scale <= 100:
        #             self.compass_scale_factor = scale
        #             print(f"罗盘倍数更新: {self.compass_scale_factor}")
        #     except ValueError:
        #         print(f"罗盘倍数输入错误: {self.ids.compass_scale_input.text}")
        #         pass
        
        print(f"开始叠加图形罗盘，位置: {self.graphic_compass_position}, 旋转角度: {self.graphic_compass_rotation}")
        print(f"背景图像形状: {img.shape}, 数据类型: {img.dtype}")
        print(f"当前罗盘倍数因子: {self.compass_scale_factor:.2f}")
        
        compass_img = self.graphic_compass_image.copy()
        h, w = compass_img.shape[:2]
        
        print(f"罗盘图像原始尺寸: {w}x{h}, 通道数: {compass_img.shape[2]}, 数据类型: {compass_img.dtype}")
        
        # 如果有旋转角度，进行旋转
        if self.graphic_compass_rotation != 0:
            print(f"应用旋转角度: {self.graphic_compass_rotation}")
            center = (w // 2, h // 2)
            rotation_matrix = cv2.getRotationMatrix2D(center, -self.graphic_compass_rotation, 1.0)
            compass_img = cv2.warpAffine(compass_img, rotation_matrix, (w, h), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
        
        # 计算质心位置
        img_h, img_w = img.shape[:2]
        
        # 使用质心位置（如果有的话），否则使用背景图像的中心
        if self.image_processor.centroid:
            center_x, center_y = self.image_processor.centroid
            print(f"使用质心位置: ({center_x}, {center_y})")
        else:
            center_x, center_y = img_w // 2, img_h // 2
            print(f"使用背景图像中心位置: ({center_x}, {center_y})")
        
        # 根据图像分辨率动态调整罗盘大小
        # 设置基准分辨率为1920x1080
        base_width, base_height = 1920, 1080
        base_area = base_width * base_height
        current_area = img_w * img_h
        
        # 计算面积比率
        area_ratio = current_area / base_area
        
        print(f"当前图像尺寸: {img_w}x{img_h}, 面积: {current_area}")
        print(f"基准图像尺寸: {base_width}x{base_height}, 面积: {base_area}")
        print(f"面积比率: {area_ratio:.2f}")
        print(f"用户缩放因子: {self.compass_scale_factor:.2f}")
        
        # 根据面积比率动态调整缩放因子
        # 面积越大，缩放因子越小；面积越小，缩放因子越大
        if area_ratio > 2.0:
            # 超高分辨率图像，使用较小的缩放因子
            scale_factor = 0.3
            print("超高分辨率图像，缩放因子: 0.3")
        elif area_ratio > 1.5:
            # 高分辨率图像，使用较小的缩放因子
            scale_factor = 0.4
            print("高分辨率图像，缩放因子: 0.4")
        elif area_ratio > 1.0:
            # 中高分辨率图像，使用中等缩放因子
            scale_factor = 0.5
            print("中高分辨率图像，缩放因子: 0.5")
        elif area_ratio > 0.5:
            # 中等分辨率图像，使用标准缩放因子
            scale_factor = 0.6
            print("中等分辨率图像，缩放因子: 0.6")
        elif area_ratio > 0.25:
            # 中低分辨率图像，使用较大的缩放因子
            scale_factor = 0.8
            print("中低分辨率图像，缩放因子: 0.8")
        else:
            # 低分辨率图像，使用很大的缩放因子
            scale_factor = 1.0
            print("低分辨率图像，缩放因子: 1.0")
        
        # 应用用户缩放因子
        scale_factor *= self.compass_scale_factor
        
        new_w = int(w * scale_factor)
        new_h = int(h * scale_factor)
        compass_img = cv2.resize(compass_img, (new_w, new_h), interpolation=cv2.INTER_AREA)
        print(f"罗盘图像原始尺寸: {w}x{h}, 缩放后尺寸: {new_w}x{new_h}")
        
        # 计算罗盘图像的放置位置（中心对齐到质心）
        x = center_x - new_w // 2
        y = center_y - new_h // 2
        self.graphic_compass_position = (x, y)
        
        print(f"罗盘图像最终位置: ({x}, {y}), 背景图像尺寸: {img_w}x{img_h}")
        
        # 处理透明通道
        if compass_img.shape[2] == 4:
            print("使用PIL库处理透明通道混合")
            alpha = compass_img[:, :, 3].astype(float) / 255.0
            print(f"alpha范围: {alpha.min():.2f} - {alpha.max():.2f}, 平均值: {alpha.mean():.2f}")
            
            # 使用PIL库来处理透明通道
            try:
                from PIL import Image as PILImage
                
                # 将OpenCV图像转换为PIL图像
                img_pil = PILImage.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
                
                # 将罗盘图像转换为PIL图像
                compass_pil = PILImage.fromarray(cv2.cvtColor(compass_img, cv2.COLOR_BGRA2RGB))
                
                # 创建alpha通道图像
                alpha_pil = PILImage.fromarray((alpha * 255).astype(np.uint8), mode='L')
                
                # 将罗盘图像和alpha通道合并
                compass_pil.putalpha(alpha_pil)
                
                # 计算放置位置
                paste_x = int(x)
                paste_y = int(y)
                
                # 粘贴罗盘图像到背景图像上
                img_pil.paste(compass_pil, (paste_x, paste_y), compass_pil)
                
                # 将PIL图像转换回OpenCV格式
                img[:, :, :] = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)
                
                print("PIL库处理完成")
            except ImportError:
                print("PIL库不可用，使用OpenCV方法")
                # 使用OpenCV的alpha混合函数
                alpha = compass_img[:, :, 3].astype(float) / 255.0
                print(f"alpha范围: {alpha.min():.2f} - {alpha.max():.2f}, 平均值: {alpha.mean():.2f}")
                
                for c in range(3):
                    img[y:y+new_h, x:x+new_w, c] = (alpha * compass_img[:, :, c].astype(float) + (1 - alpha) * img[y:y+new_h, x:x+new_w, c].astype(float)).astype(img.dtype)
        else:
            print("直接覆盖（无透明通道）")
            img[y:y+new_h, x:x+new_w] = compass_img
        
        print("图形罗盘叠加完成")
    
    def _draw_zhoutian_ring_on_image(self, img, cx, cy, text_distance):
        """在图像上绘制周天环（最外层）"""
        lines, texts, inner_radius, outer_radius = self.image_processor.draw_zhoutian_ring(
            (cx, cy), text_distance
        )
        
        # 绘制360个细线刻度（亮红色）
        for start, end in lines:
            start = (int(start[0]), int(start[1]))
            end = (int(end[0]), int(end[1]))
            cv2.line(img, start, end, (255, 0, 0), 2)
        
        # 绘制内外圆（亮红色）
        cv2.circle(img, (int(cx), int(cy)), int(inner_radius), (255, 0, 0), 5)
        cv2.circle(img, (int(cx), int(cy)), int(outer_radius), (255, 0, 0), 5)
        
        # 使用PIL绘制度数标签（亮红色）
        try:
            from PIL import Image as PILImage, ImageDraw, ImageFont
            
            # 创建PIL图像
            img_pil = PILImage.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
            draw = ImageDraw.Draw(img_pil)
            
            # 加载中文字体（稍小一些）
            try:
                font = ImageFont.truetype('C:\\Windows\\Fonts\\simhei.ttf', 16)
            except:
                font = ImageFont.load_default()
            
            # 绘制度数标签
            for x, y, label in texts:
                # 计算文字大小
                bbox = draw.textbbox((0, 0), label, font=font)
                text_width = bbox[2] - bbox[0]
                text_height = bbox[3] - bbox[1]
                
                # 绘制亮红色文字
                draw.text((int(x)-text_width//2, int(y)-text_height//2), label, font=font, fill=(255, 0, 0))
            
            # 转换回OpenCV格式
            img[:, :, :] = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)
        except ImportError:
            pass
    
    def on_touch_down(self, touch):
        """触摸按下事件处理"""
        if not self.drawing_mode and not self.graphic_compass_enabled:
            super().on_touch_down(touch)
            return
        
        if touch.is_mouse_scrolling:
            return
        
        # 检查是否点击了罗盘图像
        if self.graphic_compass_enabled and self.graphic_compass_image is not None:
            if 'image_widget' in self.ids:
                image_widget = self.ids.image_widget
                if image_widget.collide_point(*touch.pos):
                    # 转换触摸坐标到图像坐标
                    widget_pos = image_widget.pos
                    widget_size = image_widget.size
                    
                    if self.image_processor.processed_image is not None:
                        img_height, img_width = self.image_processor.processed_image.shape[:2]
                        
                        # 计算图像在widget中的实际显示区域（考虑保持比例）
                        widget_width, widget_height = widget_size
                        img_aspect = img_width / img_height
                        widget_aspect = widget_width / widget_height
                        
                        if widget_aspect > img_aspect:
                            display_height = widget_height
                            display_width = display_height * img_aspect
                        else:
                            display_width = widget_width
                            display_height = display_width / img_aspect
                        
                        offset_x = (widget_width - display_width) / 2
                        offset_y = (widget_height - display_height) / 2
                        
                        scale_x = img_width / display_width
                        scale_y = img_height / display_height
                        
                        img_x = int((touch.pos[0] - widget_pos[0] - offset_x) * scale_x)
                        img_y = int(img_height - (touch.pos[1] - widget_pos[1] - offset_y) * scale_y)
                        
                        # 检查是否点击在罗盘图像上
                        compass_x, compass_y = self.graphic_compass_position
                        compass_h, compass_w = self.graphic_compass_image.shape[:2]
                        
                        if compass_x <= img_x <= compass_x + compass_w and compass_y <= img_y <= compass_y + compass_h:
                            self.is_dragging_compass = True
                            self.compass_drag_offset = (img_x - compass_x, img_y - compass_y)
                            return
        
        # 画笔模式
        if not self.drawing_mode:
            super().on_touch_down(touch)
            return
        
        if 'image_widget' in self.ids:
            image_widget = self.ids.image_widget
            if image_widget.collide_point(*touch.pos):
                self.is_drawing = True
                self.save_history()
                
                # 转换触摸坐标到图像坐标
                widget_pos = image_widget.pos
                widget_size = image_widget.size
                
                if self.image_processor.processed_image is not None:
                    img_height, img_width = self.image_processor.processed_image.shape[:2]
                    
                    # 计算图像在widget中的实际显示区域（考虑保持比例）
                    widget_width, widget_height = widget_size
                    img_aspect = img_width / img_height
                    widget_aspect = widget_width / widget_height
                    
                    if widget_aspect > img_aspect:
                        # widget更宽，图像高度适配widget高度
                        display_height = widget_height
                        display_width = display_height * img_aspect
                    else:
                        # widget更高，图像宽度适配widget宽度
                        display_width = widget_width
                        display_height = display_width / img_aspect
                    
                    # 计算图像在widget中的偏移量
                    offset_x = (widget_width - display_width) / 2
                    offset_y = (widget_height - display_height) / 2
                    
                    # 计算缩放比例
                    scale_x = img_width / display_width
                    scale_y = img_height / display_height
                    
                    # 计算图像坐标（考虑Y轴翻转）
                    img_x = int((touch.pos[0] - widget_pos[0] - offset_x) * scale_x)
                    img_y = int(img_height - (touch.pos[1] - widget_pos[1] - offset_y) * scale_y)
                    
                    # 限制坐标在图像范围内
                    img_x = max(0, min(img_width - 1, img_x))
                    img_y = max(0, min(img_height - 1, img_y))
                    
                    self.last_x, self.last_y = img_x, img_y
                    cv2.circle(self.image_processor.processed_image, (img_x, img_y), self.brush_size//2, self.brush_color, -1)
                    self.update_image_display()
            else:
                super().on_touch_down(touch)
    
    def on_touch_move(self, touch):
        """触摸移动事件处理"""
        # 拖拽罗盘图像
        if self.is_dragging_compass and self.graphic_compass_image is not None:
            if 'image_widget' in self.ids:
                image_widget = self.ids.image_widget
                if image_widget.collide_point(*touch.pos):
                    # 转换触摸坐标到图像坐标
                    widget_pos = image_widget.pos
                    widget_size = image_widget.size
                    
                    if self.image_processor.processed_image is not None:
                        img_height, img_width = self.image_processor.processed_image.shape[:2]
                        
                        # 计算图像在widget中的实际显示区域（考虑保持比例）
                        widget_width, widget_height = widget_size
                        img_aspect = img_width / img_height
                        widget_aspect = widget_width / widget_height
                        
                        if widget_aspect > img_aspect:
                            display_height = widget_height
                            display_width = display_height * img_aspect
                        else:
                            display_width = widget_width
                            display_height = display_width / img_aspect
                        
                        offset_x = (widget_width - display_width) / 2
                        offset_y = (widget_height - display_height) / 2
                        
                        scale_x = img_width / display_width
                        scale_y = img_height / display_height
                        
                        img_x = int((touch.pos[0] - widget_pos[0] - offset_x) * scale_x)
                        img_y = int(img_height - (touch.pos[1] - widget_pos[1] - offset_y) * scale_y)
                        
                        # 更新罗盘图像位置
                        self.graphic_compass_position = (img_x - self.compass_drag_offset[0], img_y - self.compass_drag_offset[1])
                        self.update_image_display()
            return
        
        # 画笔模式
        if not self.is_drawing:
            super().on_touch_move(touch)
            return
        
        if 'image_widget' in self.ids:
            image_widget = self.ids.image_widget
            if image_widget.collide_point(*touch.pos):
                # 转换触摸坐标到图像坐标
                widget_pos = image_widget.pos
                widget_size = image_widget.size
                
                if self.image_processor.processed_image is not None:
                    img_height, img_width = self.image_processor.processed_image.shape[:2]
                    
                    # 计算图像在widget中的实际显示区域（考虑保持比例）
                    widget_width, widget_height = widget_size
                    img_aspect = img_width / img_height
                    widget_aspect = widget_width / widget_height
                    
                    if widget_aspect > img_aspect:
                        # widget更宽，图像高度适配widget高度
                        display_height = widget_height
                        display_width = display_height * img_aspect
                    else:
                        # widget更高，图像宽度适配widget宽度
                        display_width = widget_width
                        display_height = display_width / img_aspect
                    
                    # 计算图像在widget中的偏移量
                    offset_x = (widget_width - display_width) / 2
                    offset_y = (widget_height - display_height) / 2
                    
                    # 计算缩放比例
                    scale_x = img_width / display_width
                    scale_y = img_height / display_height
                    
                    # 计算图像坐标（考虑Y轴翻转）
                    img_x = int((touch.pos[0] - widget_pos[0] - offset_x) * scale_x)
                    img_y = int(img_height - (touch.pos[1] - widget_pos[1] - offset_y) * scale_y)
                    
                    # 限制坐标在图像范围内
                    img_x = max(0, min(img_width - 1, img_x))
                    img_y = max(0, min(img_height - 1, img_y))
                    
                    if self.last_x != -1 and self.last_y != -1:
                        cv2.line(self.image_processor.processed_image, (self.last_x, self.last_y), (img_x, img_y), self.brush_color, self.brush_size)
                        self.update_image_display()
                    
                    self.last_x, self.last_y = img_x, img_y
    
    def on_touch_up(self, touch):
        """触摸释放事件处理"""
        # 结束拖拽罗盘图像
        if self.is_dragging_compass:
            self.is_dragging_compass = False
            self.compass_drag_offset = (0, 0)
            return
        
        # 画笔模式
        if not self.drawing_mode:
            super().on_touch_up(touch)
            return
        
        self.is_drawing = False
        self.last_x, self.last_y = -1, -1