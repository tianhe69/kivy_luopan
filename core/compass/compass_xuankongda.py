import numpy as np
import math

class CompassXuankongda:
    """玄空大卦罗盘"""
    
    def __init__(self, rotation_angle=0):
        self.rotation_angle = rotation_angle
        
        # 三圈数据
        self.outer_hexagram_names = []
        self.outer_hexagram_angles = []
        
        self.middle_fortune_labels = []
        self.middle_fortune_angles = []
        
        self.inner_element_labels = []
        self.inner_element_angles = []
        
        # 初始化三圈
        self._init_hexagram_data()
    
    def _init_hexagram_data(self):
        """初始化六十四卦数据（从数学角度90度开始逆时针排列）"""
        # 标准玄空大卦表数据（只保留三圈：卦名、卦运、五行）
        hexagram_data = [
            # 序号, 卦名, 卦运, 五行
            (1, '乾', '一', '9'),
            (2, '夬', '六', '4'),
            (3, '有', '七', '3'),
            (4, '壮', '二', '8'),
            (5, '畜', '八', '2'),
            (6, '需', '三', '7'),
            (7, '蓄', '四', '6'),
            (8, '泰', '九', '1'),
            (9, '履', '六', '9'),
            (10, '兑', '一', '4'),
            (11, '睽', '二', '3'),
            (12, '归', '八', '8'),
            (13, '孚', '三', '2'),
            (14, '节', '七', '7'),
            (15, '损', '九', '6'),
            (16, '临', '四', '1'),
            (17, '同', '七', '9'),
            (18, '革', '三', '4'),
            (19, '离', '一', '3'),
            (20, '丰', '六', '8'),
            (21, '家', '四', '2'),
            (22, '既', '九', '7'),
            (23, '贲', '八', '6'),
            (24, '夷', '三', '1'),
            (25, '妄', '二', '9'),
            (26, '随', '七', '4'),
            (27, '噬', '六', '3'),
            (28, '震', '一', '8'),
            (29, '益', '九', '2'),
            (30, '屯', '四', '7'),
            (31, '預', '三', '6'),
            (32, '复', '八', '1'),
            (33, '坤', '一', '1'),
            (34, '剥', '六', '6'),
            (35, '比', '七', '7'),
            (36, '观', '二', '2'),
            (37, '豫', '八', '8'),
            (38, '晋', '三', '3'),
            (39, '萃', '四', '4'),
            (40, '否', '九', '9'),
            (41, '谦', '六', '1'),
            (42, '艮', '一', '6'),
            (43, '蹇', '二', '7'),
            (44, '渐', '七', '2'),
            (45, '过', '三', '8'),
            (46, '旅', '八', '3'),
            (47, '咸', '九', '4'),
            (48, '遯', '四', '9'),
            (49, '师', '七', '1'),
            (50, '蒙', '七', '6'),
            (51, '坎', '一', '7'),
            (52, '涣', '六', '2'),
            (53, '解', '四', '8'),
            (54, '未', '九', '3'),
            (55, '困', '八', '4'),
            (56, '讼', '三', '9'),
            (57, '升', '二', '1'),
            (58, '蛊', '七', '6'),
            (59, '井', '六', '7'),
            (60, '巽', '一', '2'),
            (61, '恒', '九', '8'),
            (62, '鼎', '四', '3'),
            (63, '過', '四', '4'),
            (64, '姤', '八', '9'),
        ]
        
        # 从数学角度90度开始逆时针排列一周（每5.625度一个）
        for i, (num, name, fortune, element) in enumerate(hexagram_data):
            # 从90度开始逆时针排列
            angle = 90 - i * 5.625
            if angle < 0:
                angle += 360
            
            self.outer_hexagram_names.append(name)
            self.outer_hexagram_angles.append(angle)
            
            self.middle_fortune_labels.append(fortune)
            self.middle_fortune_angles.append(angle)
            
            self.inner_element_labels.append(element)
            self.inner_element_angles.append(angle)
    
    def get_labels(self):
        """获取所有标签（兼容旧接口）"""
        return self.outer_hexagram_names + self.middle_fortune_labels + self.inner_element_labels
    
    def get_label_angles(self):
        """获取所有标签角度（兼容旧接口）"""
        return self.outer_hexagram_angles + self.middle_fortune_angles + self.inner_element_angles
    
    def get_degrees(self):
        """获取所有度数（兼容旧接口）"""
        return self.outer_hexagram_angles + self.middle_fortune_angles + self.inner_element_angles
    
    def calculate_cumulative_angles(self):
        """计算累积角度（兼容旧接口）"""
        return self.outer_hexagram_angles + self.middle_fortune_angles + self.inner_element_angles