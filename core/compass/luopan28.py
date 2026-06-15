from .base import CompassBase


class Compass28(CompassBase):
    """28宿罗盘（附加罗盘）"""
    
    def __init__(self, rotation_angle=0):
        super().__init__(rotation_angle)
        self.sector_angle = 360 / 28
        self.initial_offset = 262.5
        
        self.labels = [
            '危', '室', '壁', '奎', '娄', '胃', '昴', '毕', '觜', '参',
            '井', '鬼', '柳', '星', '张', '翼', '轸', '角', '亢', '氐', '房', '心', '尾', '箕',
            '斗', '牛', '女', '虚'
        ]
        
        self.start_angles = [
            0.00, 343.24, 327.47, 318.60, 302.83, 291.00, 277.20, 266.36, 250.59, 248.62, 239.75, 207.22, 203.28, 188.50, 181.60, 163.86, 146.12, 129.36, 117.53, 108.66, 93.88, 88.95, 84.02, 66.28, 55.44, 29.57, 21.68, 9.85
        ]
        
        self.degrees = [
            16.76, 15.77, 8.87, 15.77, 11.83, 13.8, 10.84, 15.77, 1.97, 8.87, 32.53, 3.94, 14.78, 6.9, 17.74, 17.74, 16.76, 11.83, 8.87, 14.78, 4.93, 4.93, 17.74, 10.84, 25.87, 7.89, 11.83, 9.86
        ]
        
        self.label_angles = [
            261.62, 245.355, 233.035, 220.715, 206.915, 194.1, 181.78, 168.475, 159.605, 154.185, 133.485, 115.25, 105.89, 95.05, 82.73, 64.99, 47.74, 33.445, 23.095, 11.27, 1.415, 356.485, 345.15, 330.86, 312.505, 295.625, 285.765, 274.925
        ]
        
        self.num_sectors = 28
        
        self.degrees = [
            12, 9, 15, 5, 5, 18, 11,
            26, 8, 12, 10, 17, 16, 9,
            16, 12, 14, 11, 16, 2, 9,
            33, 4, 15, 7, 18, 18, 17
        ]
    
    def get_sector_angle(self):
        return self.sector_angle
    
    def get_initial_offset(self):
        return self.initial_offset
    
    def get_labels(self):
        return self.labels
    
    def get_num_sectors(self):
        return self.num_sectors
    
    def get_degrees(self):
        """获取每个宿的度数"""
        return self.degrees
    
    def calculate_cumulative_angles(self):
        """计算累积角度（用于绘制分割线）"""
        cumulative = [0]
        for degree in self.degrees:
            cumulative.append(cumulative[-1] + degree)
        return cumulative[:-1]
