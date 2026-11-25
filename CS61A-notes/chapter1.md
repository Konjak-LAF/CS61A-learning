# Composing Programs 第一章学习笔记

本笔记覆盖 1.1 到 1.7。主线是：

1. 用表达式、语句和函数描述计算过程。
2. 用环境模型解释名字如何查找、函数如何调用、局部变量如何隔离。
3. 用高阶函数把通用计算模式抽象成函数。
4. 用装饰器在不修改原函数的前提下包装函数行为。
5. 用递归函数解决可以不断分解为同类子问题的问题。

其中环境框架图、高阶函数和函数装饰器是重点。

## 1. Python 与程序的基本元素

### 1.1 表达式与语句

Python 程序由表达式和语句组成。

表达式描述计算，求值后产生一个值：

```python
2 + 2
max(7.5, 9.5)
```

语句描述动作，执行后改变解释器状态，不一定产生值：

```python
x = 10
from math import sqrt
def square(x):
    return x * x
```

表达式可以出现在语句中，但语句本身不能被当成普通值。

### 1.2 调用表达式

调用表达式的基本结构是：

```python
operator(operand_1, operand_2, ...)
```

求值过程：

1. 求值操作符表达式，找到函数。
2. 从左到右求值操作数表达式。
3. 把函数应用到参数上。

例如：

```python
max(min(1, -2), min(pow(3, 5), -4))
```

嵌套调用形成表达式树。叶子是基本表达式，内部节点是调用表达式，值从叶子向根逐层计算。

### 1.3 名字与环境

名字通过赋值、导入和 `def` 绑定到值：

```python
radius = 10
from math import pi
def square(x):
    return x * x
```

解释器必须保存名字和值的对应关系，这种记忆称为环境。名字可以通过重新赋值指向新的值，旧绑定会被替换。

多个赋值会先求值右边，再绑定左边：

```python
x, y = 3, 4.5
y, x = x, y
```

因此交换可以直接写成 `y, x = x, y`。

### 1.4 纯函数与非纯函数

纯函数只通过参数和返回值与外界交互，相同输入总是产生相同输出：

```python
abs(-2)
pow(2, 10)
```

非纯函数会产生副作用，例如打印、修改状态或访问网络：

```python
print(2)
```

`print` 的返回值是 `None`。交互式解释器不会主动显示 `None`，但打印行为本身已经发生。

纯函数更容易组合、测试和并行执行，因此本章大部分示例都使用纯函数。

## 2. 环境模型与环境框架图

环境模型是本章最重要的内容。它解释了名字为什么会解析到正确的值，以及函数调用为什么不会互相污染。

### 2.1 Frame 与 Binding

环境由一串 frame 组成。每个 frame 可以画成一个框，框内保存若干 binding：

```text
name  ->  value
```

环境图通常包括：

- Global frame：全局 frame，程序开始时就存在。
- Local frame：函数调用时创建的新 frame。
- Binding：名字到值的绑定。
- Arrow：名字指向值的箭头。
- Function object：函数值，包含函数名、形参和父环境。

示意图：

```text
Global frame
square -> [func square(x)]
```

执行：

```python
def square(x):
    return x * x
```

会在全局 frame 中建立 `square` 的绑定。函数体的代码此时不会执行。

### 2.2 函数调用规则

调用用户定义函数时，环境按以下规则变化：

1. 在调用者环境中创建一个新的局部队。
2. 把实参绑定到形参。
3. 新 frame 的父环境是该函数定义时的环境，而不是调用者的环境。
4. 在由这个新 frame 开始的环境中执行函数体。

例如：

```python
def square(x):
    return x * x

square(-2)
```

环境图可以写为：

```text
Global frame
square -> [func square(x), parent=Global]

square call frame
parent -> Global
x -> -2
```

求值 `x * x` 时，先在当前 frame 找到 `x = -2`，结果为 4。函数返回后，局部 frame 不再处于活动调用栈中。

### 2.3 名字查找规则

查找名字时按以下顺序进行：

1. 先在当前 frame 中查找。
2. 找不到就沿着 parent 链继续查找。
3. 最终到 global frame。
4. 仍然找不到则报错。

因此，局部 frame 中的绑定可以遮蔽外层的同名绑定。

```python
x = 10

def f(x):
    return x + 1

f(3)
```

函数调用 frame 中的 `x` 是 3，全局的 `x` 是 10。函数体内的名字查找从局部 frame 开始，所以得到 4。

### 2.4 函数对象与 parent

每个用户定义函数对象都有一个 parent，指向函数被定义时的环境。

```python
def outer(a):
    def inner(b):
        return a + b
    return inner

add5 = outer(5)
```

环境图：

```text
Global frame
outer -> [func outer(a), parent=Global]
add5  -> [func inner(b), parent=outer call frame]

outer call frame
parent -> Global
a -> 5
inner -> [func inner(b), parent=outer call frame]
```

调用 `add5(3)` 时，新 frame 的 parent 是 `outer` 的调用 frame，而不是调用 `add5` 的位置。这就是词法作用域。

### 2.5 多个局部 frame 的例子

```python
from operator import add, mul

def square(x):
    return mul(x, x)

def sum_squares(x, y):
    return add(square(x), square(y))

result = sum_squares(5, 12)
```

执行 `sum_squares(5, 12)` 时：

1. 创建 `sum_squares` 的 frame，绑定 `x = 5`、`y = 12`。
2. 求值 `square(x)`，创建第一个 `square` frame，绑定 `x = 5`，返回 25。
3. 求值 `square(y)`，创建第二个独立的 `square` frame，绑定 `x = 12`，返回 144。
4. 在当前 `sum_squares` frame 中求值 `add(25, 144)`，返回 169。

局部 frame 示意：

```text
sum_squares frame
x -> 5
y -> 12

square frame 1
x -> 5

square frame 2
x -> 12
```

三个 frame 中都有名字 `x`，但它们互不影响。每次函数调用都会创建新的局部 frame，即使调用的是同一个函数。

### 2.6 嵌套定义的环境图

```python
def average(x, y):
    return (x + y) / 2

def improve(update, close, guess=1):
    while not close(guess):
        guess = update(guess)
    return guess

def sqrt(a):
    def sqrt_update(x):
        return average(x, a / x)

    def sqrt_close(x):
        return abs(x * x - a) < 0.001

    return improve(sqrt_update, sqrt_close)
```

调用 `sqrt(256)` 时，环境图的核心是：

```text
Global frame
average -> [func average(x, y), parent=Global]
improve -> [func improve(update, close, guess), parent=Global]
sqrt -> [func sqrt(a), parent=Global]

sqrt call frame
parent -> Global
a -> 256
sqrt_update -> [func sqrt_update(x), parent=sqrt call frame]
sqrt_close -> [func sqrt_close(x), parent=sqrt call frame]
```

注意两个点：

- `sqrt_update` 和 `sqrt_close` 是 `sqrt` 调用时创建的局部函数。
- 它们的 parent 是 `sqrt` call frame，因此能访问 `a`。

当 `improve` 调用 `update(guess)` 时，`update` 的形式参数绑定到了 `sqrt_update` 函数对象。调用 `sqrt_update` 创建的新 frame 的 parent 是 `sqrt` frame，而 `improve` frame 不会自动成为它的 parent。

### 2.7 环境图检查清单

画环境图时按以下顺序检查：

1. 画出 Global frame。
2. 每个 `def` 语句在**当前 frame** 中创建函数绑定。
3. 函数对象记录 intrinsic name、参数和 parent。
4. 每次函数调用创建一个新 frame。
5. 新 frame 的 parent 等于被调用函数对象的 parent。
6. 把实参绑定到形参。
7. 进入函数体，按名字查找规则求值。
8. 函数返回后，把返回值交给调用者。

这里最容易犯的错误是把“函数定义的位置”和“函数调用的位置”混为一谈。词法作用域使用的是定义位置，不是调用位置。

## 3. 设计函数、控制与测试

### 3.1 设计原则

好的函数通常满足：

- 只做一件事，名字能概括这件事。
- 不重复实现相同逻辑，遵循 DRY 原则。
- 尽量定义得通用。
- 使用文档字符串说明输入、输出和行为。

```python
def pressure(v, t, n=6.022e23):
    """Compute the pressure in pascals of an ideal gas."""
    k = 1.38e-23
    return n * k * t / v
```

默认参数让调用者可以省略常见参数：

```python
pressure(1, 273.15)
pressure(1, 273.15, 3 * 6.022e23)
```

### 3.2 语句与控制流

语句会被执行，而不是被求值。函数体可以有局部赋值：

```python
def percent_difference(x, y):
    difference = abs(x - y)
    return 100 * difference / x
```

局部赋值只会修改当前局部 frame，不会修改 global frame。

条件语句按顺序检查 clause：

```python
def absolute_value(x):
    if x > 0:
        return x
    elif x == 0:
        return 0
    else:
        return -x
```

循环语句用于重复执行：

```python
def fib(n):
    pred, curr = 0, 1
    k = 2
    while k < n:
        pred, curr = curr, pred + curr
        k = k + 1
    return curr
```

`while` 每轮先检查条件，再执行 suite。多重赋值会先求值右边所有表达式，再统一更新左边。

### 3.3 测试

断言用于验证函数行为：

```python
assert fib(8) == 13, 'The 8th Fibonacci number should be 13'
```

文档字符串可以包含 doctest：

```python
def sum_naturals(n):
    """Return the sum of the first n natural numbers.

    >>> sum_naturals(10)
    55
    """
    total, k = 0, 1
    while k <= n:
        total, k = total + k, k + 1
    return total
```

测试不仅是验证工具，也是函数使用方式的文档。

## 4. 高阶函数

### 4.1 什么是高阶函数

高阶函数是至少满足以下条件之一的函数：

- 接收一个或多个函数作为参数。
- 返回一个函数作为结果。

函数在 Python 中是一等对象，可以绑定名字、作为参数、作为返回值和放入数据结构。

### 4.2 函数作为参数

不同求和函数有相同模板：

```python
def sum_naturals(n):
    total, k = 0, 1
    while k <= n:
        total, k = total + k, k + 1
    return total

def sum_cubes(n):
    total, k = 0, 1
    while k <= n:
        total, k = total + k * k * k, k + 1
    return total
```

把变化的“第 k 项”提取成参数：

```python
def summation(n, term):
    total, k = 0, 1
    while k <= n:
        total, k = total + term(k), k + 1
    return total

def cube(x):
    return x * x * x

def sum_cubes(n):
    return summation(n, cube)
```

环境图要点：

```text
summation frame
n -> 3
term -> [func cube(x), parent=Global]
```

`term` 这个名字只是局部绑定，它的值指向 `cube` 函数对象。函数对象的 parent 仍然是 Global，因为 `cube` 在全局环境中定义。

### 4.3 嵌套定义与词法作用域

嵌套函数可以捕获外层 frame 中的名字：

```python
def make_adder(n):
    def add(x):
        return x + n
    return add

add5 = make_adder(5)
add5(10)
```

环境图：

```text
Global frame
make_adder -> [func make_adder(n), parent=Global]
add5 -> [func add(x), parent=make_adder call frame]

make_adder call frame
n -> 5
add -> [func add(x), parent=make_adder call frame]
```

调用 `add5(10)` 时：

```text
add call frame
parent -> make_adder call frame
x -> 10
```

查找 `n` 时先看当前 `add` frame，再沿着 parent 找到 `make_adder` frame 中的 `n = 5`。

### 4.4 函数作为返回值

```python
def compose1(f, g):
    return lambda x: f(g(x))
```

这个函数返回一个 lambda 函数。返回的函数对象捕获 `f` 和 `g`：

```text
compose1 call frame
f -> [func square(x), parent=Global]
g -> [func successor(x), parent=Global]
<lambda> -> [func <lambda>(x), parent=compose1 call frame]
```

因为返回的 lambda 的 parent 是 `compose1` frame，所以它之后仍能找到 `f` 和 `g`。这就是闭包。

形式化地说，闭包是：

```text
函数对象 + 函数定义时的环境
```

### 4.5 Currying

Currying 把多参数函数转换成一系列单参数函数。

```python
def curry2(f):
    def g(x):
        def h(y):
            return f(x, y)
        return h
    return g
```

满足：

```python
curry2(pow)(2)(5)
```

等价于：

```python
pow(2, 5)
```

每一步返回的函数都捕获前一步的参数。

### 4.6 Lambda 表达式

Lambda 表达式创建匿名函数：

```python
square = lambda x: x * x
```

它等价于定义一个只有单个返回表达式的函数。Lambda 不能包含赋值和复杂控制语句。

```python
compose1 = lambda f, g: lambda x: f(g(x))
```

Python 风格通常更偏好 `def`，只有在函数很短且作为参数或返回值时，lambda 才更合适。

### 4.7 一等函数

函数拥有一等地位，意味着它可以：

1. 绑定到名字。
2. 作为参数传递。
3. 作为返回值返回。
4. 放入列表、字典等数据结构。

这种能力让函数可以像数字和字符串一样被组合和传递。

## 5. 函数装饰器

### 5.1 最简单的装饰器

装饰器是一个高阶函数，用来包装另一个函数。

```python
def trace(fn):
    def wrapped(x):
        print('-> ', fn, '(', x, ')')
        return fn(x)
    return wrapped
```

使用：

```python
@trace
def triple(x):
    return 3 * x
```

这等价于：

```python
def triple(x):
    return 3 * x

triple = trace(triple)
```

### 5.2 装饰器的执行顺序

对于：

```python
@trace
def triple(x):
    return 3 * x
```

执行顺序是：

1. 创建原来的 `triple` 函数对象。
2. 求值装饰器表达式 `trace`。
3. 调用 `trace(original_triple)`。
4. 得到 `wrapped` 函数对象。
5. 把全局名字 `triple` 重新绑定到 `wrapped`。

原来的 `triple` 函数对象仍然存在，只是不再由全局名字 `triple` 直接指向。

### 5.3 装饰器环境图

执行：

```python
def trace(fn):
    def wrapped(x):
        print('-> ', fn, '(', x, ')')
        return fn(x)
    return wrapped

@trace
def triple(x):
    return 3 * x
```

环境图可以表示为：

```text
Global frame
trace -> [func trace(fn), parent=Global]
triple -> [func wrapped(x), parent=trace call frame]

trace call frame
parent -> Global
fn -> [func triple(x), parent=Global]
wrapped -> [func wrapped(x), parent=trace call frame]
```

调用 `triple(12)` 时：

```text
wrapped call frame
parent -> trace call frame
x -> 12
```

`wrapped` 查找 `fn` 时，会找到 `trace` frame 中保存的原始 `triple` 函数，然后调用它。

### 5.4 为什么装饰器能工作

关键还是闭包和名字绑定：

- `trace` 的形式参数 `fn` 捕获原函数。
- `wrapped` 的 parent 是 `trace` 的调用 frame。
- 所以 `wrapped` 之后仍然能访问 `fn`。
- 全局名字 `triple` 最终指向 `wrapped`，而不是原函数。

调用 `triple(12)` 时，实际执行的是：

```text
wrapped(12)
  -> 打印信息
  -> fn(12)
  -> 返回原 triple 的结果
```

### 5.5 装饰器表达式可以带参数

装饰器符号 `@` 后面也可以是一个调用表达式：

```python
@decorator(arg)
def f(x):
    return x
```

执行顺序是：

1. 求值 `decorator(arg)`，得到一个真正的装饰器。
2. 创建函数 `f`。
3. 把第 1 步得到的装饰器应用到 `f`。
4. 把结果绑定到名字 `f`。

写成等价形式：

```python
f = decorator(arg)(f)
```

### 5.6 装饰器与 optimize_tail_calls 的联系

Scheme 项目中的：

```python
scheme_eval = optimize_tail_calls(scheme_eval)
```

就是同一个装饰器模式。它等价于：

```python
@optimize_tail_calls
def scheme_eval(expr, env, tail=False):
    ...
```

其中：

```text
optimize_tail_calls 的参数
    -> 保存原来的 scheme_eval 函数对象

返回的 optimized_eval
    -> 成为全局名字 scheme_eval 的新值
```

因此原始函数内部看到全局 `scheme_eval` 时，实际上指向的是优化后的函数。这个绑定关系正是 trampoline 和 `Unevaluated` 能工作的关键。

## 6. 递归函数

递归函数在函数体内调用自身。

### 6.1 基本结构

递归函数通常包含：

- 一个或多个基准情况。
- 一个或多个递归调用。
- 每次递归调用都让问题变得更简单。

```python
def sum_digits(n):
    if n < 10:
        return n
    all_but_last, last = n // 10, n % 10
    return sum_digits(all_but_last) + last
```

基准情况是 `n < 10`。递归调用处理 `n // 10`，问题规模不断减小。

### 6.2 迭代与递归

迭代版本通过状态变量逐步累积：

```python
def fact_iter(n):
    total, k = 1, 1
    while k <= n:
        total, k = total * k, k + 1
    return total
```

递归版本直接表达数学定义：

```python
def fact(n):
    if n == 1:
        return 1
    return n * fact(n - 1)
```

递归调用需要等待子调用返回，因此环境图会保留多个活动 frame。

### 6.3 互递归

两个函数可以相互调用：

```python
def is_even(n):
    if n == 0:
        return True
    return is_odd(n - 1)

def is_odd(n):
    if n == 0:
        return False
    return is_even(n - 1)
```

这称为互递归。它和直接递归共享同一套环境模型和调用栈规则。

### 6.4 树递归

函数可以多次调用自身，形成树递归：

```python
def fib(n):
    if n == 0:
        return 0
    elif n == 1:
        return 1
    return fib(n - 1) + fib(n - 2)
```

`fib` 的每个调用会分成两个子调用。树递归表达简单，但可能重复计算，效率较低。

分区数问题也是树递归的典型例子：

```python
def count_partitions(n, m):
    if n == 0:
        return 1
    elif n < 0:
        return 0
    elif m == 0:
        return 0
    return (count_partitions(n - m, m) +
            count_partitions(n, m - 1))
```

它把问题分成“至少使用一个 m”和“完全不使用 m”两种情况。

## 7. 总结

第一章的核心可以压缩为四条：

1. 程序由表达式和语句组成，调用表达式先求值操作符和操作数，再应用函数。
2. 环境由 frame 和 binding 组成。函数调用创建新 frame，函数对象的 parent 决定词法作用域。
3. 高阶函数接收函数、返回函数，或同时做这两件事，从而表达通用的计算模式。
4. 装饰器是高阶函数的一种语法糖，本质是把函数传给装饰器，再把返回的新函数绑定回原名字。

环境图是理解这三件事的统一工具：

```text
函数定义
  -> 在当前 frame 绑定函数对象

函数调用
  -> 创建新 frame
  -> 绑定实参
  -> 新 frame 的 parent 指向函数定义环境

名字查找
  -> 当前 frame
  -> parent frame
  -> global frame
```

掌握这个模型后，高阶函数、闭包、装饰器和递归都不再是零散语法，而是同一套规则在不同场景下的结果。
