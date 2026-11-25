# Python 面向对象学习笔记

> 笔记来源：
>
> - [2.5 Object-Oriented Programming](https://composingprograms.com/pages/25-object-oriented-programming.html)
> - [2.6 Implementing Classes and Objects](https://composingprograms.com/pages/26-implementing-classes-and-objects.html)
> - [2.7 Object Abstraction](https://composingprograms.com/pages/27-object-abstraction.html)
>
> 适用教材：《Composing Programs》（CS61A 配套教材）第 2 章。

## 0. 三节内容如何衔接

| 章节 | 主题 | 关键词 |
| --- | --- | --- |
| 2.5 | 使用 Python 语法认识面向对象 | 类、实例、方法、属性、继承、多继承 |
| 2.6 | 用字典和函数自己实现一个对象系统 | dispatch dictionary、绑定方法、类查找 |
| 2.7 | 对象如何支持更灵活的抽象 | 泛型函数、特殊方法、多重表示、类型分派、强制转换 |

一句话理解：**2.5 学“怎么用”，2.6 揭示“可以不靠语言魔法实现”，2.7 研究“对象如何让同一套操作兼容多种类型”。**

---

## 1. 对象、类与实例（2.5.1 / 2.5.2）

### 1.1 核心概念

面向对象编程把前面章节的多种思想结合起来：

- 它像数据抽象一样，在“使用数据”和“实现数据”之间建立抽象屏障；
- 它像 dispatch dictionary 一样，让对象响应行为请求；
- 它像可变数据结构一样，让对象拥有不能从全局环境直接访问的局部状态。

常用术语：

- **object（对象）**：带有属性和方法的数据值，通过点号表示法访问。
- **class（类）**：对象的类型，也是创建对象的模板。
- **instance（实例）**：某个类的具体对象。
- **instantiate（实例化）**：创建某个类的新实例。
- **attribute（属性）**：对象上的“名字-值”对。
- **instance attribute（实例属性）**：只属于某一个对象的状态，例如账户的 `balance` 和 `holder`。
- **method（方法）**：操作对象自身状态、或完成对象相关计算的函数。

### 1.2 类语句与 `__init__`

类的定义语法：

```python
class <name>:
    <suite>
```

类语句执行时，会创建新的类并绑定到 `<name>`。类套件中的 `def` 或赋值语句会创建或修改类的属性。

`__init__` 是构造函数，它在对象创建后自动被调用。第一个参数按约定叫 `self`，代表“刚刚创建的那个实例”：

```python
class Account:
    """A bank account that has a non-negative balance."""

    def __init__(self, account_holder):
        self.balance = 0
        self.holder = account_holder

    def deposit(self, amount):
        """Increase the account balance by amount and return the new balance."""
        self.balance = self.balance + amount
        return self.balance

    def withdraw(self, amount):
        """Decrease the account balance by amount and return the new balance."""
        if amount > self.balance:
            return 'Insufficient funds'
        self.balance = self.balance - amount
        return self.balance
```

使用：

```python
>>> a = Account('Kirk')
>>> a.holder
'Kirk'
>>> a.balance
0
>>> a.deposit(15)
15
>>> a.withdraw(10)
5
>>> a.withdraw(10)
'Insufficient funds'
```

要点：

- `__init__` 中的 `account_holder` 只是局部参数；但 `self.holder = account_holder` 把名字存到了对象上，因此会持续存在。
- 每个实例拥有独立的实例属性。`a` 与 `b` 互不影响。
- 实例有唯一身份，用 `is` / `is not` 判断；赋值并不会复制对象。

```python
>>> a is a
True
>>> a is not Account('Spock')
True
>>> c = a
>>> c is a
True
```

### 1.3 方法与绑定方法

在类套件中 `def` 定义的是方法，但方法定义执行后的效果与普通函数不同：

- 方法名绑定为类的属性；
- 通过实例调用时，实例会自动作为第一个参数传给 `self`；
- 因此方法定义中显式写出 `self`，调用时却不需要传入它。

```python
>>> type(Account.deposit)
<class 'function'>
>>> type(spock_account.deposit)
<class 'method'>
```

同一个函数体既可以是普通函数，也可以是绑定方法：

```python
>>> Account.deposit(spock_account, 1001)   # 函数写法，显式传入 self
1011
>>> spock_account.deposit(1000)            # 绑定方法写法，自动绑定 self
2011
```

---

## 2. 消息传递与点表达式（2.5.3）

对象通过点表达式接收“消息”：

```text
<expression> . <name>
```

点号左侧可以是任意表达式，右侧必须是简单名字。

对应的内置函数：

```python
>>> getattr(spock_account, 'balance')
10
>>> hasattr(spock_account, 'deposit')
True
```

对象的属性包括：

1. 实例属性；
2. 类属性；
3. 类中定义的方法。

绑定方法是“函数 + 调用它的实例”的结合体：调用绑定方法时，`self` 已经被自动填入。

命名约定：

- 类名用 **CapWords** / CamelCase，如 `CheckingAccount`；
- 方法名用全小写加下划线，如 `withdraw`；
- 以单个下划线开头的属性表示“实现细节，不应被外部直接使用”。

---

## 3. 类属性与属性查找（2.5.4）

### 3.1 类属性

类属性属于类本身，被同一类的所有实例共享：

```python
class Account:
    interest = 0.02  # class attribute

    def __init__(self, account_holder):
        self.balance = 0
        self.holder = account_holder
```

```python
>>> spock_account = Account('Spock')
>>> kirk_account = Account('Kirk')
>>> spock_account.interest
0.02
>>> Account.interest = 0.04
>>> spock_account.interest
0.04
>>> kirk_account.interest
0.04
```

### 3.2 点表达式的查找规则

Python 求值 `<expression>.<name>` 时按顺序执行：

1. 求值点号左侧表达式，得到对象；
2. 在对象的**实例属性**中找 `<name>`，找到就直接返回；
3. 找不到时，到对象的**类**中找类属性；
4. 如果类属性是函数，则返回**绑定方法**。

可以类比环境中的名字查找：局部名字优先于全局名字，实例属性优先于类属性。

### 3.3 实例属性遮蔽类属性

点号出现在赋值语句左侧时，赋值只影响点号左侧的对象：

```python
>>> kirk_account.interest = 0.08   # 创建实例属性，不修改类属性
>>> kirk_account.interest
0.08
>>> spock_account.interest
0.04

>>> Account.interest = 0.05        # 修改类属性
>>> spock_account.interest
0.05
>>> kirk_account.interest          # 已有的实例属性不受影响
0.08
```

易错点总结：

| 写法 | 影响范围 |
| --- | --- |
| `instance.attr = value` | 只影响该实例 |
| `Class.attr = value` | 影响类以及所有未遮蔽该属性的实例 |
| 读取 `instance.attr` | 实例属性优先，其次类属性 |

---

## 4. 继承（2.5.5 / 2.5.6）

### 4.1 为什么需要继承

不同类之间常存在“一般 vs 特殊”的关系。例如 `CheckingAccount` 是 `Account` 的特殊化：它多数行为相同，但取款要收费、利率更低。

- **base class / superclass / parent class**：被继承的类，如 `Account`。
- **subclass / child class**：继承别人的类，如 `CheckingAccount`。
- **继承**：子类拥有基类的属性，也可以覆盖（override）部分属性或方法。

### 4.2 判断是否该用继承：is-a 与 has-a

- `CheckingAccount` **is-a** `Account`：适合继承。
- 银行 **has-a** 一组账户：应把账户列表作为银行的实例属性，而不是让银行继承账户。

### 4.3 完整例子

```python
class Account:
    """A bank account that has a non-negative balance."""

    interest = 0.02

    def __init__(self, account_holder):
        self.balance = 0
        self.holder = account_holder

    def deposit(self, amount):
        self.balance = self.balance + amount
        return self.balance

    def withdraw(self, amount):
        if amount > self.balance:
            return 'Insufficient funds'
        self.balance = self.balance - amount
        return self.balance


class CheckingAccount(Account):
    """A bank account that charges for withdrawals."""

    withdraw_charge = 1
    interest = 0.01

    def withdraw(self, amount):
        return Account.withdraw(self, amount + self.withdraw_charge)
```

```python
>>> checking = CheckingAccount('Sam')
>>> checking.deposit(10)
10
>>> checking.withdraw(5)
4
>>> checking.interest
0.01
```

解析 `checking.deposit` 时，Python 依次查找：

1. 实例属性；
2. `CheckingAccount`；
3. `Account`。

`deposit` 虽然在 `Account` 中找到，但它仍然是一个以 `CheckingAccount` 实例为 `self` 的绑定方法，而不是变成 `Account` 的实例。

### 4.4 调用被覆盖的祖先方法

- 覆盖后的属性仍可通过类对象访问，例如 `Account.withdraw(self, ...)`。
- 实现 `withdraw` 时最好写 `self.withdraw_charge` 而不是 `CheckingAccount.withdraw_charge`，这样未来新的子类也能覆盖收费值。

### 4.5 接口

**对象接口**是一组属性名以及这些属性应当满足的行为约束。

例如“账户接口”要求有 `deposit`、`withdraw` 和 `balance`。Python 不做显式接口声明：只要对象有对应名字，它就实现了该接口。

```python
>>> def deposit_all(winners, amount=5):
...     for account in winners:
...         account.deposit(amount)
```

这个函数只依赖账户抽象，不检查具体类型。反例是直接调用 `Account.deposit(account, amount)`，它假设了账户一定是 `Account`，破坏了抽象屏障。

### 4.6 多继承

Python 允许一个子类继承多个基类：

```python
class SavingsAccount(Account):
    deposit_charge = 2

    def deposit(self, amount):
        return Account.deposit(self, amount - self.deposit_charge)


class AsSeenOnTVAccount(CheckingAccount, SavingsAccount):
    def __init__(self, account_holder):
        self.holder = account_holder
        self.balance = 1  # A free dollar!
```

```python
>>> such_a_deal = AsSeenOnTVAccount("John")
>>> such_a_deal.deposit(20)   # $2 fee from SavingsAccount.deposit
19
>>> such_a_deal.withdraw(5)   # $1 fee from CheckingAccount.withdraw
13
```

对菱形继承，Python 按 **从左到右、再向上** 的顺序查找，也就是：

```python
AsSeenOnTVAccount, CheckingAccount, SavingsAccount, Account, object
```

可以查询实际的方法解析顺序：

```python
>>> [c.__name__ for c in AsSeenOnTVAccount.mro()]
['AsSeenOnTVAccount', 'CheckingAccount', 'SavingsAccount', 'Account', 'object']
```

Python 使用的具体算法称为 **C3 Method Resolution Ordering**。

---

## 5. 对象的角色（2.5.8）

对象系统鼓励**关注点分离**：

- 每个对象封装并管理自己的一部分状态；
- 每个类语句定义实现某部分逻辑的函数；
- 抽象屏障约束大型程序不同部分之间的边界。

但不是所有问题都适合用类：

- 函数式抽象更适合描述“输入 -> 输出”的关系；
- 不要把每一段逻辑都硬塞进类里；
- Python 是多范式语言，应针对问题选择合适的组织方式。

---

## 6. 用函数和字典实现对象系统（2.6）

### 6.1 目的

用 dispatch dictionary 模拟对象系统，说明“面向对象”不是语言专利：即使没有内置对象语法，也可以用函数和字典写出对象式程序。

### 6.2 实例：dispatch dictionary

实例是一张会响应 `get` / `set` 消息的字典：

```python
def bind_method(value, instance):
    """Return a bound method if value is callable, or value otherwise."""
    if callable(value):
        def method(*args):
            return value(instance, *args)
        return method
    return value


def make_instance(cls):
    """Return a new object instance, which is a dispatch dictionary."""
    def get_value(name):
        if name in attributes:
            return attributes[name]
        value = cls['get'](name)
        return bind_method(value, instance)

    def set_value(name, value):
        attributes[name] = value

    attributes = {}
    instance = {'get': get_value, 'set': set_value}
    return instance
```

说明：

- `set` 只把属性存进实例自己的 `attributes` 字典；
- `get` 先查实例属性，查不到再查类；
- 从类中查到函数值时，用 `bind_method` 把实例塞进第一个参数，模拟绑定方法。

### 6.3 类：又能查基类，又能造实例

```python
def make_class(attributes, base_class=None):
    """Return a new class, which is a dispatch dictionary."""
    def get_value(name):
        if name in attributes:
            return attributes[name]
        if base_class is not None:
            return base_class['get'](name)

    def set_value(name, value):
        attributes[name] = value

    def new(*args):
        return init_instance(cls, *args)

    cls = {'get': get_value, 'set': set_value, 'new': new}
    return cls
```

类与实例的查找方式不同：

- 实例查不到属性时，到自己的类里找；
- 类查不到属性时，到基类里找；
- 类的 `get` 不做方法绑定。

### 6.4 创建实例并初始化

```python
def init_instance(cls, *args):
    """Return a new object with type cls, initialized with args."""
    instance = make_instance(cls)
    init = cls['get']('__init__')
    if init:
        init(instance, *args)
    return instance
```

对象创建流程：

1. 由 `make_class` 创建的 `new` 被调用；
2. `init_instance` 先用 `make_instance` 制作空实例；
3. 在类中查找 `__init__`；
4. 如果存在，调用 `init(instance, *args)`；
5. 返回初始化后的实例。

### 6.5 用字典对象系统写银行账户

```python
def make_account_class():
    """Return the Account class, which has deposit and withdraw methods."""
    interest = 0.02

    def __init__(self, account_holder):
        self['set']('holder', account_holder)
        self['set']('balance', 0)

    def deposit(self, amount):
        new_balance = self['get']('balance') + amount
        self['set']('balance', new_balance)
        return self['get']('balance')

    def withdraw(self, amount):
        balance = self['get']('balance')
        if amount > balance:
            return 'Insufficient funds'
        self['set']('balance', balance - amount)
        return self['get']('balance')

    return make_class(locals())


Account = make_account_class()
kirk_account = Account['new']('Kirk')
```

```python
>>> kirk_account['get']('holder')
'Kirk'
>>> kirk_account['get']('interest')
0.02
>>> kirk_account['get']('deposit')(20)
20
>>> kirk_account['get']('withdraw')(5)
15
>>> kirk_account['set']('interest', 0.04)
>>> Account['get']('interest')
0.02
```

子类通过传入基类实现继承：

```python
def make_checking_account_class():
    """Return the CheckingAccount class, which imposes a $1 withdrawal fee."""
    interest = 0.01
    withdraw_fee = 1

    def withdraw(self, amount):
        fee = self['get']('withdraw_fee')
        return Account['get']('withdraw')(self, amount + fee)

    return make_class(locals(), Account)
```

### 6.6 与真实 Python 的关系

真实 Python 中，用户定义类的实例有一个特殊属性 `__dict__`，它保存实例属性，功能类似这里的 `attributes` 字典。Python 还额外区分了一些特殊方法，让 `len`、`repr`、运算符等内置功能能正确处理各种类型。

---

## 7. 对象抽象：字符串转换与特殊方法（2.7.1 / 2.7.2）

### 7.1 `str` 与 `repr`

Python 要求对象提供两种字符串表示：

- `str(obj)`：人类可读的文本；
- `repr(obj)`：优先返回“可以 `eval` 得到等价对象”的 Python 表达式。

```python
>>> from datetime import date
>>> tues = date(2011, 9, 12)
>>> repr(tues)
'datetime.date(2011, 9, 12)'
>>> str(tues)
'2011-09-12'
```

实现原理：`repr(x)` 实际调用 `x.__repr__()`，`str(x)` 实际调用 `x.__str__()`，所以自定义类实现这两个方法后，`repr` / `str` 自动对新类型生效。

```python
>>> tues.__repr__()
'datetime.date(2011, 9, 12)'
>>> tues.__str__()
'2011-09-12'
```

### 7.2 常用特殊方法

| 特殊方法 | 触发时机 | 说明 |
| --- | --- | --- |
| `__init__` | 构造对象 | 初始化实例属性 |
| `__repr__` | `repr(obj)`、交互式显示 | 尽可能返回可求值的表达式 |
| `__str__` | `str(obj)`、`print(obj)` | 返回人类可读文本 |
| `__bool__` | `bool(obj)` 或布尔上下文 | 自定义真假值 |
| `__len__` | `len(obj)` | 自定义长度 |
| `__getitem__` | `obj[key]`、切片等 | 自定义下标访问 |
| `__call__` | `obj(...)` | 让对象像函数一样可调用 |
| `__add__` / `__radd__` | `x + y` | 左操作数/右操作数的加法协议 |
| `__mul__` / `__rmul__` | `x * y` | 左操作数/右操作数的乘法协议 |

对象真假值的规则：

- 默认用户定义对象为真；
- 定义了 `__bool__` 时调用它；
- 没有 `__bool__` 时，定义过 `__len__` 的对象用长度判断：空为假，非空为真。

```python
>>> Account.__bool__ = lambda self: self.balance != 0
>>> bool(Account('Jack'))
False
>>> if not Account('Jack'):
...     print('Jack has nothing')
Jack has nothing
```

运算符协议示例：`x + y` 先看 `x.__add__`，再看 `y.__radd__`。

### 7.3 可调用对象

```python
class Adder:
    def __init__(self, n):
        self.n = n

    def __call__(self, k):
        return self.n + k


>>> add_three_obj = Adder(3)
>>> add_three_obj(4)
7
```

`Adder(3)` 对象和 `make_adder(3)` 返回的函数效果相同，这模糊了“数据”和“函数”的界限。

---

## 8. 多重表示（2.7.3）

### 8.1 问题

同一个抽象数据可能同时存在多种合理表示。例如复数既可以用直角坐标 `(real, imag)` 表示，也可以用极坐标 `(magnitude, angle)` 表示。

### 8.2 共享接口

先定义一个不直接实例化的基类 `Number`，它只负责把运算符转发到 `add` / `mul`：

```python
class Number:
    def __add__(self, other):
        return self.add(other)

    def __mul__(self, other):
        return self.mul(other)
```

`Complex` 假设所有复数都有 `real`、`imag`、`magnitude`、`angle` 四个属性：

```python
class Complex(Number):
    def add(self, other):
        return ComplexRI(self.real + other.real,
                         self.imag + other.imag)

    def mul(self, other):
        magnitude = self.magnitude * other.magnitude
        return ComplexMA(magnitude, self.angle + other.angle)
```

两种复数表示类需要保持“同一组坐标描述同一个点”。

### 8.3 用 `@property` 按需计算属性

直角坐标类存储 `real` / `imag`，极坐标属性按需计算：

```python
from math import atan2

class ComplexRI(Complex):
    def __init__(self, real, imag):
        self.real = real
        self.imag = imag

    @property
    def magnitude(self):
        return (self.real ** 2 + self.imag ** 2) ** 0.5

    @property
    def angle(self):
        return atan2(self.imag, self.real)

    def __repr__(self):
        return 'ComplexRI({0:g}, {1:g})'.format(self.real, self.imag)
```

极坐标类存储 `magnitude` / `angle`，直角坐标属性按需计算：

```python
from math import sin, cos, pi

class ComplexMA(Complex):
    def __init__(self, magnitude, angle):
        self.magnitude = magnitude
        self.angle = angle

    @property
    def real(self):
        return self.magnitude * cos(self.angle)

    @property
    def imag(self):
        return self.magnitude * sin(self.angle)

    def __repr__(self):
        return 'ComplexMA({0:g}, {1:g} * pi)'.format(
            self.magnitude, self.angle / pi
        )
```

```python
>>> ri = ComplexRI(5, 12)
>>> ri.real
5
>>> ri.magnitude
13.0
>>> ri.real = 9
>>> ri.magnitude
15.0

>>> ComplexRI(1, 2) + ComplexMA(2, pi / 2)
ComplexRI(1, 4)
>>> ComplexRI(0, 1) * ComplexRI(0, 1)
ComplexMA(1, 1 * pi)
```

接口方案的优点：

- 各种表示类可以独立开发，只需约定共享属性名和行为条件；
- 接口是“可加”的，后续添加第三种表示只需要再写一个实现同一接口的类。

---

## 9. 泛型函数（2.7.4）

**generic function（泛型函数）** 是能接受多种不同类型参数的函数。原文介绍三种实现方式：

1. 共享接口（shared interface）；
2. 类型分派（type dispatching）；
3. 类型强制转换（coercion）。

### 9.1 共享接口

`Complex.add` 能接受 `ComplexRI` 或 `ComplexMA`，因为两者共享接口。写成有理数类时，只要也实现 `add` / `mul`，就能参与同一套 `Number` 运算符逻辑：

```python
from math import gcd

class Rational(Number):
    def __init__(self, numer, denom):
        g = gcd(numer, denom)
        self.numer = numer // g
        self.denom = denom // g

    def __repr__(self):
        return 'Rational({0}, {1})'.format(self.numer, self.denom)

    def add(self, other):
        nx, dx = self.numer, self.denom
        ny, dy = other.numer, other.denom
        return Rational(nx * dy + ny * dx, dx * dy)

    def mul(self, other):
        return Rational(self.numer * other.numer,
                        self.denom * other.denom)
```

> 提示：教材原文写作 `from fractions import gcd`，但新版本 Python 中推荐使用 `from math import gcd`。

共享接口的问题：`Rational + Complex` 时两者虽然有 `add`，但各自 `add` 无法理解对方的结构，需要另想办法。

### 9.2 类型分派

类型分派就是先检查参数类型，再选择对应实现。

`isinstance(obj, cls)` 检查对象是否属于某类或其子类：

```python
>>> isinstance(ComplexRI(1, 1), ComplexRI)
True
>>> isinstance(ComplexRI(1, 1), Complex)
True
>>> isinstance(ComplexRI(1, 1), ComplexMA)
False
```

一个简单例子：

```python
def is_real(c):
    """Return whether c is a real number with no imaginary part."""
    if isinstance(c, ComplexRI):
        return c.imag == 0
    if isinstance(c, ComplexMA):
        return c.angle % pi == 0
```

更结构化的做法是给类型打标签：

```python
Rational.type_tag = 'rat'
Complex.type_tag = 'com'
```

同标签直接用 `add` / `mul`；不同标签查交叉类型操作表：

```python
def add_complex_and_rational(c, r):
    return ComplexRI(c.real + r.numer / r.denom, c.imag)


def mul_complex_and_rational(c, r):
    r_magnitude, r_angle = r.numer / r.denom, 0
    if r_magnitude < 0:
        r_magnitude, r_angle = -r_magnitude, pi
    return ComplexMA(c.magnitude * r_magnitude, c.angle + r_angle)


def add_rational_and_complex(r, c):
    return add_complex_and_rational(c, r)


def mul_rational_and_complex(r, c):
    return mul_complex_and_rational(c, r)


class Number:
    adders = {
        ('com', 'rat'): add_complex_and_rational,
        ('rat', 'com'): add_rational_and_complex,
    }
    multipliers = {
        ('com', 'rat'): mul_complex_and_rational,
        ('rat', 'com'): mul_rational_and_complex,
    }

    def __add__(self, other):
        if self.type_tag == other.type_tag:
            return self.add(other)
        if (self.type_tag, other.type_tag) in self.adders:
            return self.cross_apply(other, self.adders)

    def __mul__(self, other):
        if self.type_tag == other.type_tag:
            return self.mul(other)
        if (self.type_tag, other.type_tag) in self.multipliers:
            return self.cross_apply(other, self.multipliers)

    def cross_apply(self, other, cross_fns):
        cross_fn = cross_fns[(self.type_tag, other.type_tag)]
        return cross_fn(self, other)
```

```python
>>> ComplexRI(1.5, 0) + Rational(3, 2)
ComplexRI(3, 0)
>>> Rational(-1, 2) * ComplexMA(4, pi / 2)
ComplexMA(2, 1.5 * pi)
```

字典驱动的分派更容易扩展：新类型安装自己的 `type_tag`，并向 `adders` / `multipliers` 添加交叉操作。

> 复现提示：如果按教材的展示顺序在同一个脚本中依次执行，`Complex`、`Rational` 在定义时已经绑定了最初的 `Number` 类；重新执行 `class Number: ...` 只会创建新类，不会改写旧类的继承关系。若要实际运行，应把最终带类型分派的 `Number` 定义放在 `Complex`、`Rational` 之前，或者直接给已有的 `Number` 类动态添加 `adders`、`multipliers` 和 `cross_apply`。

### 9.3 类型强制转换

如果一种类型可以无损（或近似）地看作另一种类型，就不必为每个操作都写交叉函数。

例如有理数可以强制转换为虚部为 0 的复数：

```python
def rational_to_complex(r):
    return ComplexRI(r.numer / r.denom, 0)


class Number:
    coercions = {('rat', 'com'): rational_to_complex}

    def __add__(self, other):
        x, y = self.coerce(other)
        return x.add(y)

    def __mul__(self, other):
        x, y = self.coerce(other)
        return x.mul(y)

    def coerce(self, other):
        if self.type_tag == other.type_tag:
            return self, other
        if (self.type_tag, other.type_tag) in self.coercions:
            return self.coerce_to(other.type_tag), other
        if (other.type_tag, self.type_tag) in self.coercions:
            return self, other.coerce_to(self.type_tag)

    def coerce_to(self, other_tag):
        coercion_fn = self.coercions[(self.type_tag, other_tag)]
        return coercion_fn(self)
```

强制转换方案只需要“每种类型对之间一个转换函数”，而不是“每种操作、每种类型对各写一个交叉函数”。

> 同样地，使用强制转换版本时，也要保证 `Complex`、`Rational` 最终继承的是带 `coerce` / `coerce_to` 的 `Number`，否则既有实例仍会走旧类的 `__add__` / `__mul__`。

可能的扩展：

- 把两种类型都转换成第三种公共类型（如菱形和矩形都可被看作四边形）；
- 迭代强制转换，经中间类型完成转换（如整数 -> 有理数 -> 实数）。

缺点：

- 转换可能丢失信息，例如精确的有理数转为复数后变成了近似浮点数；
- Python 早期有 `__coerce__` 特殊方法，因复杂度问题最终被移除，改为各运算符自己决定如何转换。

### 9.4 三种实现方式对比

| 方式 | 核心思想 | 优点 | 代价 |
| --- | --- | --- | --- |
| 共享接口 | 不同类实现同名方法 | 简单、符合对象模型 | 跨类型组合仍需额外处理 |
| 类型分派 | 按类型标签或 `isinstance` 选择实现 | 可同时利用两种表示 | 交叉操作表会随类型增多而膨胀 |
| 强制转换 | 把一种类型转成另一种再运算 | 每对类型只需一个转换函数 | 可能丢失信息，转换规则可能复杂 |

---

## 10. 复习要点与易错点

1. **实例属性 vs 类属性**：读取时实例属性覆盖类属性；赋值给实例只影响该实例。
2. **`self` 不要漏**：方法定义必须写 `self`，调用时由 Python 自动传入。
3. **绑定方法 vs 普通函数**：`Account.deposit` 是普通函数，`spock_account.deposit` 是绑定方法。
4. **继承不是复制粘贴**：只写子类与基类的差异；被覆盖的基类方法仍可通过 `Base.method(self, ...)` 调用。
5. **多继承顺序**：默认从左到右、再向上，用 `.mro()` 查看实际解析顺序。
6. **明确接口优于检查类型**：能用 `account.deposit(...)` 就不要写 `Account.deposit(account, ...)`。
7. **`str` 与 `repr` 不同**：前者给人看，后者尽量给 Python 求值器看。
8. **`@property` 不是方法调用**：它让零参数函数以属性形式访问，同时保持坐标一致性。
9. **泛型函数三种路线**：共享接口、类型分派、强制转换；各有适用场景和代价。
10. **对象系统可以自行实现**：2.6 证明了对象只需要“查自己、查类、绑定 self、调用构造器”几个机制。

---

## 参考资料

- [Composing Programs 2.5 Object-Oriented Programming](https://composingprograms.com/pages/25-object-oriented-programming.html)
- [Composing Programs 2.6 Implementing Classes and Objects](https://composingprograms.com/pages/26-implementing-classes-and-objects.html)
- [Composing Programs 2.7 Object Abstraction](https://composingprograms.com/pages/27-object-abstraction.html)
- [Python Data Model: Special method names](https://docs.python.org/3/reference/datamodel.html#special-method-names)
