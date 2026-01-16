import cv2
import numpy as np
from core.compass.compass_manager import CompassManager
import os


class ImageProcessor:
    """图像处理器"""
    
    def __init__(self):
        self.image = None
        self.original_image = None
        self.processed_image = None
        self.points = None
        self.centroid = None
        self.compass_manager = CompassManager()
        self.threshold_lower = 100
        self.threshold_upper = 200
        self.show_compass = False
        self.compass_lines = []
        self.compass_texts = []
        self.target_min_size = 1380  # 图像调整的默认最小尺寸阈值
    
    def load_image(self, image_path):
        """加载图像"""
        try:
            nparr = np.fromfile(image_path, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if img is None:
                return False
            self.image = img
            self.original_image = img.copy()
            self.processed_image = img.copy()
            return True
        except Exception as e:
            print(f"加载图像失败: {e}")
            return False
    
    def calculate_centroid(self, points):
        """计算质心"""
        if not points or len(points) < 3:
            return None
        points_array = np.array(points)
        M = cv2.moments(points_array)
        if M['m00'] == 0:
            return None
        cx = int(M['m10'] / M['m00'])
        cy = int(M['m01'] / M['m00'])
        return (cx, cy)
    
    def apply_threshold_separation(self, img, lower, upper):
        """应用色调分离"""
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        h, s, v = cv2.split(hsv)
        
        mask = cv2.inRange(h, np.array([lower]), np.array([upper]))
        result = cv2.bitwise_and(img, img, mask=mask)
        
        return result
    
    def draw_compass(self, centroid, line_length, text_distance, image_width, image_height,
                   line_color=(0, 165, 255), text_color=(0, 0, 255), 
                   linewidth=2.5, fontsize=14):
        """绘制罗盘"""
        if not self.compass_manager.current_compass or not centroid:
            return [], []
        
        cx, cy = centroid
        compass = self.compass_manager.current_compass
        lines = []
        texts = []
        
        # 周天度数环的外圆半径（与draw_zhoutian_ring中的计算一致）
        outer_radius_zhoutian = text_distance - 5
        inner_radius_zhoutian = outer_radius_zhoutian - 30
        
        # 将24山和12支的显示半径设置为比周天度数内圈少2个字符，再扩充12像素
        adjusted_text_distance = inner_radius_zhoutian - fontsize * 2 + 12
        
        for i in range(compass.get_num_sectors()):
            x_end, y_end = compass.calculate_line_end(cx, cy, line_length, i)
            lines.append(((cx, cy), (x_end, y_end)))
            
            label_x, label_y = compass.calculate_label_position(cx, cy, adjusted_text_distance, i)
            texts.append((label_x, label_y, compass.get_labels()[i]))
        
        return lines, texts
    
    def get_compass_types(self):
        """获取罗盘类型"""
        return self.compass_manager.get_compass_types()
    
    def set_compass_type(self, compass_type):
        """设置罗盘类型"""
        if compass_type is None:
            self.show_compass = False
            return False
        success = self.compass_manager.set_compass_type(compass_type)
        if success:
            self.show_compass = True
        return success
    
    def set_rotation_angle(self, angle):
        """设置旋转角度"""
        self.compass_manager.set_rotation_angle(angle)
    
    def get_rotation_angle(self):
        """获取旋转角度"""
        return self.compass_manager.get_rotation_angle()
    
    def draw_compass28(self, centroid, text_distance, line_color=(0, 165, 255), text_color=(0, 0, 255), linewidth=2.5, fontsize=14):
        """绘制28宿罗盘（附加罗盘）"""
        if not self.compass_manager.show_compass28 or not centroid:
            return [], []
        
        cx, cy = centroid
        compass28 = self.compass_manager.compass28
        labels = compass28.get_labels()
        degrees = compass28.get_degrees()
        cumulative_angles = compass28.calculate_cumulative_angles()
        
        # 获取旋转角度
        rotation_angle = self.compass_manager.get_rotation_angle()
        
        # 计算周天度数环的半径
        outer_radius_zhoutian = text_distance - 5
        inner_radius_zhoutian = outer_radius_zhoutian - 30
        
        # 计算12地支圈的半径（比周天度数内圈少2个字符）
        compass12_radius = inner_radius_zhoutian - fontsize * 2
        
        # 28宿圈的半径比12地支半径少2个字符，再扩大20像素
        outer_radius = compass12_radius - fontsize * 2 + 20
        inner_radius = outer_radius - 30
        
        texts = []
        
        for i, (label, label_angle) in enumerate(zip(labels, compass28.label_angles)):
            # 加上旋转角度
            label_angle_with_rotation = label_angle + rotation_angle
            label_angle_rad = np.deg2rad(label_angle_with_rotation)
            
            # 将28宿字符显示压在两圆之间（内圆和外圆的中间），字号缩小到75%
            label_radius = (inner_radius + outer_radius) / 2
            label_fontsize = int(fontsize * 0.75)
            
            label_x = cx + label_radius * np.cos(label_angle_rad)
            label_y = cy + label_radius * np.sin(label_angle_rad)
            
            texts.append((label_x, label_y, label))
        
        return [], texts, inner_radius, outer_radius
    
    def draw_xuankongda(self, centroid, text_distance, line_color=(0, 165, 255), text_color=(0, 0, 255), linewidth=2.5, fontsize=14):
        """绘制玄空大卦罗盘"""
        print(f"draw_xuankongda被调用: show_xuankongda={self.compass_manager.show_xuankongda}, centroid={centroid}")
        if not self.compass_manager.show_xuankongda or not centroid:
            return [], []
        
        cx, cy = centroid
        xuankongda = self.compass_manager.compass_xuankongda
        
        # 获取旋转角度
        rotation_angle = self.compass_manager.get_rotation_angle()
        
        # 计算周天度数环的半径
        outer_radius_zhoutian = text_distance - 5
        inner_radius_zhoutian = outer_radius_zhoutian - 30
        
        # 计算12地支圈的半径（比周天度数内圈少2个字符）
        compass12_radius = inner_radius_zhoutian - fontsize * 2
        
        # 玄空大卦盘的最大半径比12地支圈少4个字符
        outer_radius = compass12_radius - fontsize * 4
        
        # 将玄空大卦盘的三圈显示半径整体缩小5%
        outer_radius *= 0.95
        
        # 三圈半径（按比例缩放）
        middle_radius = outer_radius * 0.93
        inner_radius = outer_radius * 0.86
        
        # 绘制三圈之间的环线
        lines = []
        
        # 为每圈定义不同的颜色（BGR格式）
        inner_color = (255, 0, 0)      # 蓝色
        middle_color = (0, 255, 255)    # 黄色
        outer_color = (0, 0, 255)       # 红色
        
        # 计算每圈的内半径和外半径
        outer_circle_inner = outer_radius * 0.99
        outer_circle_outer = outer_radius * 1.03
        middle_circle_inner = middle_radius * 0.99
        middle_circle_outer = middle_radius * 1.03
        inner_circle_inner = inner_radius * 0.98
        inner_circle_outer = inner_radius * 1.01
        
        # 生成精细刻度线（360条，与周天度数盘一致）
        for angle in range(360):
            angle_deg = angle + rotation_angle
            angle_rad = np.deg2rad(angle_deg)
            
            # 内圈刻度线（蓝色）
            start_x = cx + inner_circle_inner * np.cos(angle_rad)
            start_y = cy + inner_circle_inner * np.sin(angle_rad)
            end_x = cx + inner_circle_outer * np.cos(angle_rad)
            end_y = cy + inner_circle_outer * np.sin(angle_rad)
            lines.append(((start_x, start_y), (end_x, end_y), inner_color))
            
            # 中圈刻度线（黄色）
            start_x = cx + middle_circle_inner * np.cos(angle_rad)
            start_y = cy + middle_circle_inner * np.sin(angle_rad)
            end_x = cx + middle_circle_outer * np.cos(angle_rad)
            end_y = cy + middle_circle_outer * np.sin(angle_rad)
            lines.append(((start_x, start_y), (end_x, end_y), middle_color))
            
            # 外圈刻度线（红色）
            start_x = cx + outer_circle_inner * np.cos(angle_rad)
            start_y = cy + outer_circle_inner * np.sin(angle_rad)
            end_x = cx + outer_circle_outer * np.cos(angle_rad)
            end_y = cy + outer_circle_outer * np.sin(angle_rad)
            lines.append(((start_x, start_y), (end_x, end_y), outer_color))
        
        # 绘制三圈文字
        outer_texts = []
        middle_texts = []
        inner_texts = []
        
        for i in range(64):
            angle = xuankongda.outer_hexagram_angles[i] + rotation_angle
            angle_rad = np.deg2rad(angle)
            
            # 最外圈：星运
            label_x = cx + outer_radius * np.cos(angle_rad)
            label_y = cy + outer_radius * np.sin(angle_rad)
            outer_texts.append((label_x, label_y, xuankongda.middle_fortune_labels[i]))
            
            # 中圈：卦名
            label_x = cx + middle_radius * np.cos(angle_rad)
            label_y = cy + middle_radius * np.sin(angle_rad)
            middle_texts.append((label_x, label_y, xuankongda.outer_hexagram_names[i]))
            
            # 内圈：五行
            label_x = cx + inner_radius * np.cos(angle_rad)
            label_y = cy + inner_radius * np.sin(angle_rad)
            inner_texts.append((label_x, label_y, xuankongda.inner_element_labels[i]))
        
        # 绘制每两卦之间的分隔线
        for i in range(64):
            # 计算当前卦和下一个卦的中间角度
            current_angle = xuankongda.outer_hexagram_angles[i] + rotation_angle
            next_index = (i + 1) % 64
            next_angle = xuankongda.outer_hexagram_angles[next_index] + rotation_angle
            
            # 计算中间角度
            mid_angle = (current_angle + next_angle) / 2
            mid_angle_rad = np.deg2rad(mid_angle)
            
            # 绘制分隔线（在内圈和外圈之间）
            start_x = cx + inner_circle_outer * np.cos(mid_angle_rad)
            start_y = cy + inner_circle_outer * np.sin(mid_angle_rad)
            end_x = cx + outer_circle_inner * np.cos(mid_angle_rad)
            end_y = cy + outer_circle_inner * np.sin(mid_angle_rad)
            lines.append(((start_x, start_y), (end_x, end_y)))
            
            # 每八卦之间设两倍粗的单分隔线（每8卦一组）
            if i % 8 == 7:
                # 绘制一条两倍粗的分隔线
                start_x = cx + inner_circle_outer * np.cos(mid_angle_rad)
                start_y = cy + inner_circle_outer * np.sin(mid_angle_rad)
                end_x = cx + outer_circle_inner * np.cos(mid_angle_rad)
                end_y = cy + outer_circle_inner * np.sin(mid_angle_rad)
                lines.append(((start_x, start_y), (end_x, end_y), 2))  # 2倍粗
        
        print(f"玄空大卦罗盘文字数量: 外圈={len(outer_texts)}, 中圈={len(middle_texts)}, 内圈={len(inner_texts)}")
        return lines, outer_texts + middle_texts + inner_texts, inner_radius, outer_radius
    
    def draw_zhoutian_ring(self, centroid, text_distance):
        """绘制周天环（最外层）"""
        if not centroid:
            return [], []
        
        cx, cy = centroid
        texts = []
        
        # 获取旋转角度
        rotation_angle = self.compass_manager.get_rotation_angle()
        
        # 周天环半径（外圆在图像边缘向内5像素，内圆在外圆向内30像素）
        outer_radius = text_distance - 5
        inner_radius = outer_radius - 30
        
        # 生成360个刻度线
        lines = []
        for i in range(360):
            angle_deg = i + rotation_angle
            angle_rad = np.deg2rad(angle_deg)
            x1 = cx + inner_radius * np.cos(angle_rad)
            y1 = cy + inner_radius * np.sin(angle_rad)
            x2 = cx + outer_radius * np.cos(angle_rad)
            y2 = cy + outer_radius * np.sin(angle_rad)
            lines.append(((x1, y1), (x2, y2)))
        
        # 生成每隔10度的度数标签
        for i in range(0, 360, 10):
            angle_deg = (i + 270 + rotation_angle) % 360
            angle_rad = np.deg2rad(angle_deg)
            
            # 标签半径放在内外圆中间
            label_radius = (inner_radius + outer_radius) / 2
            label_x = cx + label_radius * np.cos(angle_rad)
            label_y = cy + label_radius * np.sin(angle_rad)
            
            degree_num = int(i) % 360
            texts.append((label_x, label_y, str(degree_num)))
        
        return lines, texts, inner_radius, outer_radius
    
    def crop_blank_area(self, img):
        """自动裁剪空白区域"""
        # 转换为灰度图
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # 阈值化处理，将空白区域变为黑色，内容区域变为白色
        _, thresh = cv2.threshold(gray, 10, 255, cv2.THRESH_BINARY)
        
        # 查找轮廓
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        if not contours:
            return img
        
        # 找到最大的轮廓
        max_contour = max(contours, key=cv2.contourArea)
        
        # 计算边界框
        x, y, w, h = cv2.boundingRect(max_contour)
        
        # 裁剪图像
        cropped_img = img[y:y+h, x:x+w]
        
        return cropped_img
    
    def resize_image(self, img, target_min_size=1380):
        """调整图像大小：
        - 如果某维度小于target_min_size，则将其扩充到target_min_size，另一维度同比扩大
        - 如果两个维度都大于target_min_size，则将小一点的维度降为target_min_size，另一维度等比缩小
        """
        height, width = img.shape[:2]
        
        # 计算当前宽高比
        aspect_ratio = width / height
        
        # 情况1：至少有一个维度小于target_min_size
        if width < target_min_size or height < target_min_size:
            # 计算需要缩放的维度
            if width < height:
                new_width = target_min_size
                new_height = int(new_width / aspect_ratio)
            else:
                new_height = target_min_size
                new_width = int(new_height * aspect_ratio)
            
            # 使用插值方法保持清晰度（默认使用INTER_CUBIC）
            resized_img = cv2.resize(img, (new_width, new_height), interpolation=cv2.INTER_CUBIC)
        # 情况2：两个维度都大于target_min_size
        else:
            # 计算需要缩小的维度
            if width < height:
                new_width = target_min_size
                new_height = int(new_width / aspect_ratio)
            else:
                new_height = target_min_size
                new_width = int(new_height * aspect_ratio)
            
            # 使用插值方法保持清晰度（默认使用INTER_AREA，适合缩小图像）
            resized_img = cv2.resize(img, (new_width, new_height), interpolation=cv2.INTER_AREA)
        
        return resized_img
    
    def process_image(self, img):
        """处理图像：
        1. 裁剪空白区域
        2. 调整图像大小
        """
        # 第一步：裁剪空白区域
        cropped_img = self.crop_blank_area(img)
        
        # 第二步：调整图像大小，使用实例变量target_min_size作为最小尺寸
        processed_img = self.resize_image(cropped_img, target_min_size=self.target_min_size)
        
        return processed_img