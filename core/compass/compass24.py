from .base import CompassBase


class Compass24(CompassBase):
    """24山罗盘"""
    
    def __init__(self, rotation_angle=0):
        super().__init__(rotation_angle)
        self.sector_angle = 15
        self.initial_offset = 262.5
        self.labels = ['子', '癸', '丑', '艮', '寅', '甲', '卯', '乙', '辰', '巽', 
                     '巳', '丙', '午', '丁', '未', '坤', '申', '庚', '酉', '辛', 
                     '戌', '乾', '亥', '壬']
        self.num_sectors = 24
    
    def get_sector_angle(self):
        return self.sector_angle
    
    def get_initial_offset(self):
        return self.initial_offset
    
    def get_labels(self):
        return self.labels
    
    def get_num_sectors(self):
        return self.num_sectors