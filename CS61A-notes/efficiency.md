# CS61A 2.8 Efficiency 学习笔记：`count` 与 `memo` 的修饰

> 原文：
>
> - [Composing Programs 2.8 Efficiency](https://composingprograms.com/pages/28-efficiency.html)
>
> 本文重点整理两个高阶函数：
>
> - `count`：给函数套一层“调用计数器”。
> - `memo`：给函数套一层“结果缓存”。
>
> 它们在 Python 中都可以作为**装饰器（decorator）**使用，也就是原文所说的“修饰”。

---

## 0. 先抓住核心

| 工具 | 包装了什么 | 内部保存什么 | 对外改变什么 |
| --- | --- | --- | --- |
| `count(f)` | 返回一个调用 `f` 的新函数 | `call_count` 计数 | 不改变结果，只记录调用次数 |
| `memo(f)` | 返回一个先查缓存再调用 `f` 的新函数 | `cache` 字典 | 重复输入不再重新计算，直接返回缓存值 |

两者都是**高阶函数**：

```python
def count(f):
    ...
    return counted


def memo(f):
    ...
    return memoized
```

它们接收函数，返回替代函数，因此也可以写成装饰器：

```python
@count
def f(...):
    ...
```

等价于：

```python
def f(...):
    ...

f = count(f)
```

---

## 1. 为什么需要 `count`：先看见重复计算

教材用树递归版斐波那契数列作为低效程序的典型：

```python
def fib(n):
    if n == 0:
        return 0
    if n == 1:
        return 1
    return fib(n - 2) + fib(n - 1)
```

这个函数的结果不大，但计算过程中会重复计算大量子问题。例如计算 `fib(5)` 时，`fib(3)` 会在左右不同分支中反复出现。

直接统计运行时间不稳定，因为不同机器、不同 Python 版本、当前系统负载都会影响结果。更可靠的方式是统计某个事件发生的次数，例如函数被调用多少次。

于是有了 `count`：

```python
def count(f):
    def counted(*args):
        counted.call_count += 1
        return f(*args)
    counted.call_count = 0
    return counted
```

使用它：

```python
fib = count(fib)
print(fib(19))          # 4181
print(fib.call_count)   # 13529
```

只为了得到 `4181`，函数却被调用了 `13529` 次。这正是树递归低效的体现。

---

## 2. `count` 修饰器到底做了什么

### 2.1 `count(f)` 返回的不是原函数

```python
def count(f):
    def counted(*args):
        counted.call_count += 1
        return f(*args)
    counted.call_count = 0
    return counted
```

调用 `count(f)` 后得到的是内部的 `counted` 函数，而不是原来的 `f`。

因此：

```python
fib = count(fib)
```

执行后，全局名字 `fib` 已经指向 `counted`；原来的斐波那契函数被保存在 `counted` 的闭包中，也就是 `f` 这个名字对应的位置。

### 2.2 计数器挂在哪里

```python
counted.call_count = 0
```

这里不是创建全局变量，而是给 `counted` 这个函数对象添加属性。

原因是 Python 的函数也是对象，可以拥有属性。因此：

```python
fib = count(fib)

fib(5)
print(fib.call_count)  # 调用次数
```

`call_count` 属于当前这次 `count` 包装出来的函数。另一次包装会得到另一个独立计数器：

```python
f1 = count(f)
f2 = count(f)

f1()
f1()
f2()

print(f1.call_count)   # 2
print(f2.call_count)   # 1
```

### 2.3 每次调用先加一，再执行原函数

```python
def counted(*args):
    counted.call_count += 1
    return f(*args)
```

流程是：

1. 包装函数 `counted` 被调用；
2. `call_count` 加一；
3. 把收到的参数原样传给原函数 `f`；
4. 返回原函数的结果。

`*args` 让 `count` 可以包装不同参数的函数，而不只适用于单参数的 `fib`。

### 2.4 为什么递归调用也会被统计

这是理解 `count` 的关键。

```python
def fib(n):
    if n == 0:
        return 0
    if n == 1:
        return 1
    return fib(n - 2) + fib(n - 1)

fib = count(fib)
```

原函数 `fib` 内部的递归表达式仍然写着：

```python
fib(n - 2)
fib(n - 1)
```

但 Python 的名字查找发生在函数**运行时**，不是定义时。到真正调用时，全局名字 `fib` 已经被重新绑定为 `counted`，所以递归调用也会先进入包装函数，于是也会增加计数。

如果没有把全局名字 `fib` 重新绑定，而只是换一个名字保存包装函数：

```python
counted_fib = count(fib)
counted_fib(19)
print(counted_fib.call_count)   # 1
```

此时原函数内部的递归调用仍会查找全局名字 `fib`，而它仍然指向原函数，因此不会经过 `counted`。所以教材要写：

```python
fib = count(fib)
```

这样才能让后续的递归调用也进入包装函数。使用 `@count` 装饰器时，Python 会自动完成这个重新绑定。

### 2.5 装饰器写法

下面的写法：

```python
@count
def fib(n):
    if n == 0:
        return 0
    if n == 1:
        return 1
    return fib(n - 2) + fib(n - 1)
```

完全等价于：

```python
def fib(n):
    if n == 0:
        return 0
    if n == 1:
        return 1
    return fib(n - 2) + fib(n - 1)

fib = count(fib)
```

装饰器语法中的 `@count` 只是把最后一步重新绑定的过程写在了函数定义前面。

---

## 3. `memo` 修饰器：把算过的结果记下来

### 3.1 什么是 memoization

Memoization 的核心思想：

> 如果函数之前已经用相同参数计算过结果，就把结果缓存起来，下一次不再重新计算。

它不是“记忆”（memory），而是“缓存函数结果”。英文常写作 memoization，对应的包装函数名为 `memo`。

### 3.2 教材中的原始实现

```python
def memo(f):
    cache = {}

    def memoized(n):
        if n not in cache:
            cache[n] = f(n)
        return cache[n]

    return memoized
```

逐行理解：

1. `cache = {}` 创建缓存字典；
2. `memoized(n)` 是新的替代函数；
3. `if n not in cache` 判断这个参数有没有算过；
4. 没算过时，调用 `f(n)` 并把返回值存入 `cache[n]`；
5. 无论有没有命中，都返回 `cache[n]`。

### 3.3 为什么不能写成 `if not cache[n]`

这是一个常见错误：

```python
# 错误写法示例
if not cache[n]:
    cache[n] = f(n)
```

如果函数正常返回 `0`、`False`、`None` 或空集合，这些结果本身可能是“假值”，但仍然是已经计算过的有效结果。

因此必须判断“键是否存在”：

```python
if n not in cache:
    ...
```

### 3.4 `memo` 的装饰器写法

```python
@memo
def fib(n):
    if n == 0:
        return 0
    if n == 1:
        return 1
    return fib(n - 2) + fib(n - 1)
```

它等价于：

```python
def fib(n):
    ...

fib = memo(fib)
```

当 `fib(5)` 第一次运行时：

1. 外层 `memoized(5)` 发现 `5` 不在缓存；
2. 调用原函数 `f(5)`；
3. 原函数内部调用全局名字 `fib`，此时它已经是 `memoized`；
4. 递归产生的重复参数会查缓存，已经算过的直接返回。

### 3.5 为什么缓存必须使用“参数”做键

`cache` 的形状类似：

```python
{
    0: 0,
    1: 1,
    2: 1,
    3: 2,
    4: 3,
}
```

所以参数必须可以作为字典的键，也就是必须可哈希（hashable）。通常这意味着参数应当是数字、字符串、元组等不可变对象。

下面这样会失败：

```python
@memo
def f(lst):
    return sum(lst)

f([1, 2, 3])
# TypeError: unhashable type: 'list'
```

### 3.6 推广到多个参数

教材版本只适用于单参数 `n`。如果希望支持任意参数，可以把参数打包成元组：

```python
def memo(f):
    cache = {}

    def memoized(*args):
        if args not in cache:
            cache[args] = f(*args)
        return cache[args]

    return memoized
```

因为 `args` 本身是元组，只要每个参数都不可变，就能作为字典键。

---

## 4. `count` 和 `memo` 组合时的顺序

原文中最重要的一段是：

```python
counted_fib = count(fib)
fib = memo(counted_fib)
```

然后：

```python
fib(19)                 # 4181
counted_fib.call_count  # 20
```

继续调用：

```python
fib(34)                 # 5702887
counted_fib.call_count  # 35
```

为什么？

### 4.1 先经过 `memo`，再决定是否经过 `count`

组合关系是：

```text
fib
= memo(count(original_fib))
```

调用过程如下：

```text
调用 fib(n)
    |
    v
memoized(n) 查缓存
    |
    +-- 缓存命中：直接返回结果，不调用 counted
    |
    +-- 缓存未命中：调用 counted(n)
                         |
                         v
                    call_count += 1
                         |
                         v
                    调用 original_fib(n)
```

所以此时 `call_count` 统计的是：

> 缓存未命中的次数，也就是真正调用原函数 `f` 的次数。

由于每个不同的 `n` 最多只会真正计算一次，`fib(19)` 涉及输入 `0` 到 `19`，共 20 个不同参数，因此计数是 `20`。

之后调用 `fib(34)`：

- `0` 到 `19` 已经缓存；
- 新计算 `20` 到 `34`，共 15 个新参数；
- 总计 `20 + 15 = 35`。

### 4.2 调用链示意

计算 `fib(5)` 时，大致过程是：

```text
memoized(5) 未命中 -> counted(5) -> original_fib(5)
    original_fib(5)
        请求 memoized(3)
        请求 memoized(4)

memoized(3) 未命中 -> counted(3) -> original_fib(3)
    original_fib(3)
        请求 memoized(1)
        请求 memoized(2)

memoized(2) 未命中 -> counted(2) -> original_fib(2)
    ...

memoized(4) 未命中 -> counted(4) -> original_fib(4)
    original_fib(4)
        请求 memoized(2)  # 这次命中缓存，不再 counted
        请求 memoized(3)  # 这次命中缓存，不再 counted
```

这说明 `memo` 在**外**、`count` 在**内**时，计数针对的是每个不同输入第一次真正发生的计算。

### 4.3 用装饰器表达同样的顺序

组合顺序：

```python
counted_fib = count(fib)
fib = memo(counted_fib)
```

对应装饰器：

```python
@memo
@count
def fib(n):
    ...
```

装饰器从下往上应用：

1. 先执行 `fib = count(fib)`；
2. 再执行 `fib = memo(fib)`。

结果就是 `memo(count(fib))`。

如果要观察 `call_count`，最好保留显式名字：

```python
counted_fib = count(fib)
fib = memo(counted_fib)

fib(19)
print(counted_fib.call_count)
```

因为写成两个装饰器时，`count` 返回的包装函数被藏在 `memo` 的闭包里，不方便直接访问它的 `call_count`。

### 4.4 反过来修饰会怎样

```python
fib = count(memo(fib))
```

对应：

```python
@count
@memo
def fib(n):
    ...
```

这次 `count` 在最外层，因此每一次进入 `memoized` 包装函数都会增加计数，包括缓存命中的调用。

所以最后统计到的数字会更大。对于同一段递归斐波那契代码，调用 `fib(19)` 时，外层 `count` 得到的是所有经过 memoized 层的调用次数，而不是“原函数真正计算了多少个不同输入”。

一句话：

```text
memo(count(f))：count 在内，统计缓存未命中/真正计算次数
count(memo(f))：count 在外，统计所有包装函数调用，包括缓存命中
```

### 4.5 顺序总结表

| 写法 | 等价关系 | `call_count` 的含义 |
| --- | --- | --- |
| `@memo` 在 `@count` 上方 | `memo(count(f))` | 缓存未命中次数，也就是真正调用原函数次数 |
| `@count` 在 `@memo` 上方 | `count(memo(f))` | 每次进入 memoized 包装函数都计数，包括缓存命中 |

### 4.6 效率变化

不带 `memo` 的树递归斐波那契：

```python
fib = count(fib)
fib(19)
fib.call_count      # 13529
```

它的调用次数随着输入指数增长，通常写成 `Θ(φ^n)`。

带 `memo` 后：

```python
counted_fib = count(fib)
fib = memo(counted_fib)
fib(19)
counted_fib.call_count   # 20
```

每个不同参数只真正计算一次，第一次计算 `fib(n)` 大约需要 `n + 1` 次原函数调用，因此时间复杂度降为 `Θ(n)`；缓存也大约需要 `Θ(n)` 空间。

注意：这里假设一次数值运算花费常数时间。如果研究任意精度大整数的乘法成本，实际模型会更复杂；CS61A 的这一结论基于通常的算法分析模型。

---

## 5. 与 `count` 相关的 `count_frames`

原文还给出了 `count_frames`，它不是统计“总共调用了多少次”，而是统计“同时有多少个调用还没返回”：

```python
def count_frames(f):
    def counted(*args):
        counted.open_count += 1
        counted.max_count = max(counted.max_count, counted.open_count)
        result = f(*args)
        counted.open_count -= 1
        return result

    counted.open_count = 0
    counted.max_count = 0
    return counted
```

示例：

```python
fib = count_frames(fib)
fib(19)

print(fib.open_count)  # 0，调用结束后全部返回
print(fib.max_count)   # 19，历史上同时处于活跃状态的最大帧数
```

区别是：

- `count` 的 `call_count` 是累计次数；
- `count_frames` 的 `open_count` 是当前活跃调用数；
- `max_count` 是活跃调用数的历史最大值，可理解为递归过程的最大深度。

如果考虑异常情况，更稳健的版本会把递减放进 `try/finally`，保证即使原函数抛异常，`open_count` 也能恢复。

---

## 6. 2.8 节其他效率要点

### 6.1 用事件次数代替精确计时

程序运行时间依赖机器配置和具体实现，因此算法分析更关注：

- 函数调用次数；
- 基本语句执行次数；
- 活跃环境帧数量；
- 随输入规模增长的趋势。

### 6.2 Theta 记号

若资源函数 `R(n)` 在足够大的 `n` 下满足：

```text
k1 * f(n) <= R(n) <= k2 * f(n)
```

就记作：

```text
R(n) = Θ(f(n))
```

其直观含义是：忽略常数因子和低阶项，只看增长级别。

例如：

```text
Θ(n) 和 Θ(500n) 是同一级别
Θ(log2 n) 和 Θ(log10 n) 是同一级别
Θ(n^2 + n) 化简为 Θ(n^2)
```

### 6.3 常见增长类别

| 类别 | 记号 | 输入翻倍时的大致变化 | 例子 |
| --- | --- | --- | --- |
| 常数 | `Θ(1)` | 不变 | `abs` |
| 对数 | `Θ(log n)` | 少量增加 | `fast_exp` |
| 线性 | `Θ(n)` | 约翻倍 | 线性递归函数、memo 后的 fib |
| 平方 | `Θ(n^2)` | 约四倍 | 双层线性查找 |
| 指数 | `Θ(b^n)` | 增长极快 | 未 memo 的树递归 fib |

### 6.4 快速幂

原文用连续平方减少乘法次数：

```python
def square(x):
    return x * x


def fast_exp(b, n):
    if n == 0:
        return 1
    if n % 2 == 0:
        return square(fast_exp(b, n // 2))
    else:
        return b * fast_exp(b, n - 1)
```

`fast_exp(2, 1000)` 只需要约 14 次乘法，而不是 1000 次，体现对数级增长 `Θ(log n)`。

---

## 7. 易错点清单

1. `count` 统计的是包装函数的调用次数，不是原始函数自动拥有的属性。
2. 在使用 `fib = count(fib)` 后，递归调用也会经过包装函数，因此会被计数。
3. `memo` 的缓存应使用 `if n not in cache`，不能用 `if not cache[n]`。
4. `memo` 要求参数可哈希；列表、字典等可变对象不能直接作为缓存键。
5. `memo` 适合纯函数。若函数依赖随机数、当前时间或会修改外部状态，缓存可能返回过期或错误结果。
6. `memo(count(f))` 和 `count(memo(f))` 的含义不同，装饰器顺序很重要。
7. 想访问 `call_count` 时，显式写成 `counted_fib = count(fib)` 通常比把所有装饰器叠在一起更方便。
8. 缓存会占用内存。工程中常用 `functools.lru_cache(maxsize=...)` 或 `functools.cache` 控制缓存策略。

---

## 8. 复习自测

### 题 1

```python
def f(n):
    return n * 2

f = count(f)
f(1)
f(2)
print(f.call_count)
```

输出是什么？

答案：`2`。包装函数被调用了两次。

### 题 2

```python
@memo
def f(n):
    print("computing", n)
    return n * n

f(3)
f(3)
f(4)
```

输出中 `"computing"` 会出现几次？

答案：两次，分别是 `3` 和 `4`。第二次 `f(3)` 命中缓存，不再执行原函数。

### 题 3

为什么原文的 `fib(19)` 在 `memo(count(fib))` 下计数是 20？

答案：因为真正调用原函数的次数等于不同参数的个数。`fib(19)` 的过程会覆盖 `0, 1, 2, ..., 19` 共 20 个不同输入，每个输入只在第一次计算时经过 `count`。

---

## 9. 一句话总结

`count` 通过闭包和函数属性记录调用次数；`memo` 通过闭包中的字典缓存参数到结果的映射。把它们套在递归函数上时，不仅要知道“是否使用”，还要明确**谁在外、谁在内**，因为它直接决定统计的是缓存未命中次数，还是包含缓存命中在内的全部调用次数。
