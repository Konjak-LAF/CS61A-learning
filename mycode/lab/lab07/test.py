class A:
    x, y = 0, 0
    def __init__(self):
        return                                                                                    
class B(A):
    def __init__(self):
        return                                                                                    
class C(A):
    def __init__(self):
        return

B.x = 2
print(A.x, B.x, C.x)
A.x += 1
print(A.x, B.x, C.x)