from .base import CompassBase


class Compass12(CompassBase):
    """12支罗盘"""
    
    def __init__(self, rotation_angle=0):
        super().__init__(rotation_angle)
        self.sector_angle = 30
        self.initial_offset = 255
        self.labels = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥']
        self.num_sectors = 12
    
    def get_sector_angle(self):
        return self.sector_angle
    
    def get_initial_offset(self):
        return self.initial_offset
    
    def get_labels(self):
        return self.labels
    
    def get_num_sectors(self):
        return self.num_sectors