from compass.compass24 import Compass24
from compass.compass12 import Compass12
from compass.luopan28 import Compass28


class CompassManager:
    """罗盘管理器"""
    
    def __init__(self):
        self.compass_types = {
            '24山': Compass24,
            '12支': Compass12,
            '28宿': Compass28,
        }
        self.current_compass = None
        self.compass_type = None
        self.show_compass28 = False
        self.compass28 = Compass28()
    
    def get_compass_types(self):
        """获取所有罗盘类型"""
        return list(self.compass_types.keys())
    
    def set_compass_type(self, compass_type, rotation_angle=0):
        """设置罗盘类型"""
        if compass_type in self.compass_types:
            self.compass_type = compass_type
            self.current_compass = self.compass_types[compass_type](rotation_angle)
            return True
        return False
    
    def toggle_compass28(self):
        """切换28宿罗盘显示"""
        self.show_compass28 = not self.show_compass28
    
    def get_current_compass(self):
        """获取当前罗盘对象"""
        return self.current_compass
    
    def set_rotation_angle(self, angle):
        """设置旋转角度"""
        if self.current_compass:
            self.current_compass.rotation_angle = angle
        if self.compass28:
            self.compass28.rotation_angle = angle
    
    def get_rotation_angle(self):
        """获取旋转角度"""
        if self.current_compass:
            return self.current_compass.rotation_angle
        return 0
    
    def get_compass_type(self):
        """获取当前罗盘类型"""
        return self.compass_type