from abc import ABC, abstractmethod
import numpy as np


class CompassBase(ABC):
    """罗盘基类"""
    
    def __init__(self, rotation_angle=0):
        self.rotation_angle = rotation_angle
        self.sector_angle = None
        self.initial_offset = None
        self.labels = None
        self.num_sectors = None
    
    @abstractmethod
    def get_sector_angle(self):
        """获取扇区角度"""
        pass
    
    @abstractmethod
    def get_initial_offset(self):
        """获取初始偏移角度"""
        pass
    
    @abstractmethod
    def get_labels(self):
        """获取标签列表"""
        pass
    
    @abstractmethod
    def get_num_sectors(self):
        """获取扇区数量"""
        pass
    
    def calculate_line_end(self, cx, cy, line_length, i):
        """计算线条终点坐标"""
        angle_deg = i * self.sector_angle + self.rotation_angle + self.initial_offset
        angle_rad = np.deg2rad(angle_deg)
        x_end = cx + line_length * np.cos(angle_rad)
        y_end = cy + line_length * np.sin(angle_rad)
        return x_end, y_end
    
    def calculate_label_position(self, cx, cy, text_distance, i):
        """计算标签位置"""
        angle_deg = i * self.sector_angle + self.rotation_angle + self.initial_offset
        label_angle_deg = angle_deg + self.sector_angle / 2
        label_angle_rad = np.deg2rad(label_angle_deg)
        label_x = cx + text_distance * np.cos(label_angle_rad)
        label_y = cy + text_distance * np.sin(label_angle_rad)
        return label_x, label_y