# Composing Programs Chapter 3 学习笔记

本章的主题从“写程序”转向“理解程序如何被执行”。前三章已经建立了函数、数据、抽象等核心概念，这一章把它们推向一个更根本的问题：编程语言本身也是可以被程序处理的数据。Python 代码只是文本，真正让它产生计算意义的是解释器；而解释器本身又是一个普通程序。因此，理解解释器就是理解语言语义的关键。

本章的主线可以概括为：

1. Scheme 子集提供了一个极简但完整的语言模型。
2. 异常机制让程序在错误发生时改变控制流，并为解释器的 REPL 提供容错能力。
3. Calculator 解释器展示了从文本到 token、到表达式树、再到求值结果的完整路径。
4. Scheme 解释器进一步引入环境、名字绑定和用户自定义过程，形成 `eval` 与 `apply` 的互递归结构。
5. “程序即数据”使解释器成为一种通用机器：它接收描述其他机器的程序，并模拟它运行。

## 1. 从语言使用者到语言设计者

3.1 节最重要的观点是：解释器只是一个程序，它决定了表达式的含义。

Python 代码在执行前只是文本。解释器读取这些文本，按照语言的求值规则和执行规则进行计算。也就是说，语言的语义不是文本天然携带的，而是由解释器赋予的。

这改变了程序员的视角：我们不只是语言的使用者，也可以成为语言的设计者。用一种语言去实现另一种语言，被称为“元语言抽象”。

许多解释器都有一个共同结构：两个互相递归的核心函数。

- 一个负责在环境中求值表达式；
- 一个负责把函数应用到参数上。

二者的关系是循环的：

- 求值一个调用表达式时，需要把操作符和操作数求值成过程与参数，然后应用过程；
- 应用一个用户自定义过程时，又需要在新的环境中求值它的函数体。

Scheme 是本章选择的对象语言。它是一个 Lisp 方言，语法极简，核心是表达式而不是语句。本章使用的 Scheme 子集甚至没有可变值，却仍然能表达许多通用计算。

## 2. Scheme 与函数式编程

### 2.1 表达式

Scheme 程序由表达式组成，主要分为两类：调用表达式和特殊形式。

调用表达式使用前缀表示法，操作符放在括号内的最前面：

```scheme
(quotient 10 2)
(+ (* 3 5) (- 10 6))
```

这和 Python 的调用表达式语义相同：先求值操作符表达式和操作数表达式，再把得到的过程应用到参数上。区别主要是语法形式，Scheme 用括号显式标出组合结构。

`if` 是一种特殊形式：

```scheme
(if <predicate> <consequent> <alternative>)
```

它看起来像调用表达式，但求值规则不同。解释器先求值谓词部分；若为真，只求值 consequent；若为假，只求值 alternative。这个“只求值必要分支”的性质正是特殊形式的意义。

布尔特殊形式包括：

```scheme
(and e1 e2 ...)
(or e1 e2 ...)
(not e)
```

`and` 从左到右求值，遇到假值即返回假并短路；若全为真，返回最后一个值。`or` 遇到第一个真值即返回它并短路。它们和 `if` 一样都不是普通函数调用，因为参数不一定全部求值。

### 2.2 定义与过程

给值命名：

```scheme
(define pi 3.14)
```

定义过程：

```scheme
(define (square x)
  (* x x))
```

一般形式是：

```scheme
(define (<name> <formal-parameters>) <body>)
```

匿名过程使用 `lambda`：

```scheme
(lambda (x) (* x x))
```

以下两种定义等价：

```scheme
(define (plus4 x) (+ x 4))
(define plus4 (lambda (x) (+ x 4)))
```

这说明命名过程本质上是把一个 `lambda` 表达式产生的 Procedure 对象绑定到名字上。

Scheme 支持局部定义和词法作用域。例如求平方根的过程可以在函数体内部定义 `good-enough?`、`improve`、`sqrt-iter`，它们只在 `sqrt` 的作用域内可见。这种嵌套定义让递归算法的组织方式非常清晰。

### 2.3 pair 与 list

Scheme 的复合值建立在 pair 上：

```scheme
(define x (cons 1 2))
(car x)  ; 1
(cdr x)  ; 2
```

`cons` 构造 pair，`car` 取第一部分，`cdr` 取第二部分。

递归列表就是嵌套 pair：

```scheme
(cons 1
      (cons 2
            (cons 3
                  (cons 4 nil))))
```

它等价于：

```scheme
(list 1 2 3 4)
```

`nil` 或 `'()` 表示空表。可以用 `null?` 判断列表是否为空。

例如：

```scheme
(define (length items)
  (if (null? items)
      0
      (+ 1 (length (cdr items)))))

(define (getitem items n)
  (if (= n 0)
      (car items)
      (getitem (cdr items) (- n 1))))
```

这两个例子体现了 Scheme 对递归列表的自然处理方式：先把问题分解为首元素和剩余列表，再递归处理剩余部分。

### 2.4 quote 与符号数据

Scheme 的一个重要特点是符号本身可以作为数据被处理。

```scheme
(define a 1)
(define b 2)

(list a b)   ; (1 2)，求值 a 和 b
(list 'a 'b) ; (a b)，得到符号本身
```

单引号表示引用。它阻止表达式被求值，使代码可以作为数据处理。

例如：

```scheme
(car '(a b c)) ; a
(cdr '(a b c)) ; (b c)
```

引用是 Lisp 系语言的核心机制之一。没有它，`a` 会被当作名字去环境中查找；有了它，`a` 就表示符号 `a` 本身。这也为后面“程序即数据”的解释器设计埋下伏笔。

## 3. 异常：控制流的非局部跳转

### 3.1 抛出与处理

异常用于表示程序运行中的特殊情况。它不是简单的返回错误码，而是一种中断当前执行流、直接跳转到合适处理位置的机制。

Python 中可以使用 `raise` 抛出异常：

```python
raise Exception("An error occurred")
```

也可以使用 `try/except` 处理：

```python
try:
    x = 1 / 0
except ZeroDivisionError as e:
    print(type(e))
    x = 0
```

执行顺序是：

1. 进入 `try` suite；
2. 若发生匹配的异常，当前 suite 中后续语句不再执行；
3. 控制流跳转到最近的、能处理该异常类型的 `except` suite；
4. 异常对象绑定到 `as` 后的名字，仅在该 `except` suite 内有效。

异常会沿着函数调用栈向外传播，直到找到合适的 `try`，否则导致程序终止并打印 traceback。

### 3.2 异常对象与模块化

异常本身也是对象，继承自 `BaseException`。自定义异常类可以携带额外信息，例如迭代算法失败时的最后估计值。

一个典型模式是：

```python
class IterImproveError(Exception):
    def __init__(self, last_guess):
        self.last_guess = last_guess
```

内层算法在遇到 `ValueError` 时抛出 `IterImproveError(guess)`，外层捕获这个异常并读取 `e.last_guess`。这样，算法主体和错误处理逻辑被分离开来。

这种分离正是异常的模块化价值：正常计算路径不必到处写错误分支，错误策略可以集中在合适的边界处处理。

在本章后续的解释器中，异常也直接用于 REPL：语法错误、类型错误、除零错误不会让整个解释器崩溃，而是被捕获、报告，然后让用户继续输入。

## 4. Calculator 解释器：从文本到值

### 4.1 语言定义

Calculator 是一个 Scheme 语法的算术语言，只支持 `+`、`-`、`*`、`/`。

示例：

```scheme
(+ 1 2 3 4) ; 10
(+)         ; 0
(* 1 2 3 4) ; 24
(*)         ; 1
(- 10 1 2 3) ; 4
(- 3)        ; -3
(/ 15 12)    ; 1.25
(/ 10)       ; 0.1
```

加法和乘法可以接受任意个参数，空参数时分别返回单位元 0 和 1。减法和除法有单参数特殊规则：单参数减法表示取负，单参数除法表示取倒数。

这个语言很小，但已经包含嵌套组合：

```scheme
(- 100 (* 7 (+ 8 (/ -12 -3))))
```

解释器必须正确处理嵌套表达式的递归求值。

### 4.2 表达式树

解释器不能直接对字符串求值，需要先把文本转换成结构化数据。

在 Calculator 中：

- 数字是原始表达式；
- 调用表达式是一个 Scheme list；
- list 由嵌套 pair 表示。

Python 实现中通常定义 `Pair` 类和唯一 `nil` 对象：

```python
Pair(1, Pair(2, nil))
```

它的 Scheme 打印形式是：

```scheme
(1 2)
```

嵌套表达式：

```scheme
(+ (* 3 4) 5)
```

对应结构：

```python
Pair('+',
     Pair(Pair('*', Pair(3, Pair(4, nil))),
          Pair(5, nil)))
```

这说明表达式树本质上就是嵌套列表，也就是嵌套 pair。解释器的解析阶段把线性文本变成这种树形结构，求值阶段再递归地处理树。

### 4.3 解析：词法分析与语法分析

解析分为两步。

第一步是词法分析，把字符串切分成 token：

```python
tokenize_line('(+ 1 (* 2.3 45))')
# ['(', '+', 1, '(', '*', 2.3, 45, ')', ')']
```

token 是最小语法单位，包括括号、符号和数字。多字符数字会被识别并转换成数值类型。

第二步是语法分析，把 token 序列变成表达式树。这个过程通常是树递归的，因为读到一个 `(` 后，需要递归读取其中每个子表达式，直到遇到 `)`。

一个简化结构是：

- `scheme_read` 读取一个完整表达式；
- 遇到 `(` 时进入 `read_tail`；
- `read_tail` 递归读取列表首元素和剩余元素；
- 遇到 `)` 时结束当前列表。

语法错误应尽量给出明确信息，例如多余的右括号、非法数字、未闭合表达式等。这会极大提升解释器的可用性。

### 4.4 求值：eval 与 apply 的分工

Calculator 求值器的核心可以概括为：

```python
def calc_eval(exp):
    if isinstance(exp, (int, float)):
        return exp
    elif isinstance(exp, Pair):
        args = exp.second.map(calc_eval)
        return calc_apply(exp.first, args)
    else:
        raise TypeError("not a number or call expression")
```

数字是自求值表达式，直接返回。调用表达式则分两步：

1. 对所有操作数递归调用 `calc_eval`，得到参数值列表；
2. 调用 `calc_apply`，把操作符应用到参数上。

`calc_apply` 根据 operator 分派具体运算，并检查参数个数。例如加法对所有参数求和，减法处理取负和多参数相减，未知操作符抛出 `TypeError`。

这里的结构就是“按表达式类型分派”：

- 数字：返回自身；
- Pair：递归求值操作数，再应用操作符；
- 其他：报错。

### 4.5 REPL 与容错

REPL 是 Read-Eval-Print Loop：

1. Read：读取输入并解析成表达式；
2. Eval：求值；
3. Print：打印结果；
4. Loop：继续下一轮输入。

没有异常处理时，一次语法错误或除零错误就可能让 REPL 退出。加入 `try/except` 后，解释器可以打印错误信息并继续运行：

```python
while True:
    try:
        src = buffer_input()
        while src.more_on_line:
            expression = scheme_read(src)
            print(calc_eval(expression))
    except (SyntaxError, TypeError, ValueError, ZeroDivisionError) as err:
        print(type(err).__name__ + ":", err)
    except (KeyboardInterrupt, EOFError):
        return
```

这解释了 3.3 节为什么要先讲异常：异常机制是解释器保持交互稳定性的关键。

## 5. Scheme 解释器：加入抽象

Calculator 只有组合，没有抽象：不能命名值，不能定义新过程，也没有环境模型。因此它不算通用编程语言。

完整 Scheme 解释器的核心变化是引入：

- 名字绑定；
- 环境与 frame；
- `lambda` 过程；
- 用户自定义过程的应用；
- `define`、`if`、`and`、`or` 等特殊形式。

### 5.1 总体结构

Scheme 解释器仍可沿用 Calculator 的框架：

```text
输入文本
  -> tokenizer
  -> parser
  -> expression tree
  -> scheme_eval(expr, env)
  -> scheme_apply(procedure, args, env)
  -> result
```

解析器需要比 Calculator 更完整，至少要支持：

- quote；
- dotted list；
- 特殊形式；
- 嵌套表达式。

例如：

```scheme
(car '(1 . 2))
```

解析后应包含 `Pair(1, 2)` 这样的 dotted pair，而不是普通列表。

### 5.2 scheme_eval

`scheme_eval` 负责按表达式形式分派：

```python
def scheme_eval(expr, env):
    if scheme_symbolp(expr):
        return env[expr]
    elif scheme_atomp(expr):
        return expr
    first, rest = expr.first, expr.second
    if first == "lambda":
        return do_lambda_form(rest, env)
    elif first == "define":
        return do_define_form(rest, env)
    else:
        procedure = scheme_eval(first, env)
        args = rest.map(lambda operand: scheme_eval(operand, env))
        return scheme_apply(procedure, args, env)
```

主要情况包括：

- 符号：到环境中查找绑定值；
- 原子表达式：直接返回；
- `lambda`：创建 LambdaProcedure；
- `define`：在当前 frame 中建立绑定；
- 调用表达式：先求值操作符和操作数，再应用过程。

特殊形式必须在求值操作数之前识别。例如 `define` 的参数不能先当作普通操作数全部求值，`if` 的分支不能全部求值。

### 5.3 scheme_apply

过程分为两类。

第一类是 PrimitiveProcedure，用 Python 实现，例如 `+`、`car`、`cdr`。应用时直接调用其绑定的 Python 函数。

第二类是 LambdaProcedure，用 Scheme 定义。应用时需要：

1. 创建一个新 frame；
2. 将 frame 的 parent 设为该过程的定义环境；
3. 在新 frame 中把形参绑定到实参；
4. 在这个新环境中求值过程体。

这和 Python 的环境模型一致。闭包的关键不是“当前调用者的环境”，而是“过程被定义时的环境”。

### 5.4 eval/apply 互递归

完整解释器的核心是一对互相递归的函数：

```text
eval 表达式
  -> 遇到调用表达式
  -> eval 操作符和操作数
  -> apply 过程到参数
  -> 若是 LambdaProcedure
  -> 在新环境中 eval 过程体
  -> 又可能遇到新的调用表达式
```

递归的出口是语言原语：

- eval 的出口是自求值表达式和某些特殊形式；
- apply 的出口是内置 primitive procedure。

这对互递归是几乎所有解释器的骨架。

## 6. 环境与 Frame

环境由一串 frame 组成，每个 frame 维护一个从符号到值的绑定表，并指向 parent frame。

查找名字时：

1. 先查当前 frame；
2. 找不到就查 parent；
3. 一直到 global frame；
4. 仍找不到则报未绑定名字错误。

定义名字时，总是在当前 frame 写入绑定。

以阶乘为例：

```scheme
(define (factorial n)
  (if (= n 0)
      1
      (* n (factorial (- n 1)))))

(factorial 5)
```

定义过程时，解释器会：

1. 检查 `define` 表达式的格式；
2. 从 `(factorial n)` 中取出函数名和形参；
3. 创建 LambdaProcedure，保存形参、函数体和定义环境；
4. 在当前 frame 中把 `factorial` 绑定到该过程。

调用 `(factorial 5)` 时：

1. 查找 `factorial`，得到 LambdaProcedure；
2. 创建一个新 frame，parent 是定义时的 global frame；
3. 在新 frame 中绑定 `n = 5`；
4. 在这个环境中求值函数体；
5. 函数体中的递归调用继续创建新的 frame。

环境模型把名字查找、函数定义、函数调用和递归统一了起来。

## 7. 程序即数据

3.5 最后提出了一个深刻观点：解释器可以看作通用机器。

一个程序可以描述一台抽象机器。例如 `factorial` 描述了一台包含比较、乘法、递减和递归调用部件的机器。Scheme 解释器接收这样的程序描述，然后把自己配置成这台机器的模拟器。

从用户角度看：

```scheme
(+ 2 2)
```

是编程语言中的表达式。

从解释器角度看，它只是需要按照规则处理的数据结构。用户程序就是解释器的数据。

Scheme 的 `run` 和 Python 的 `eval` 都体现了这一点：

```python
eval("2 + 2")
```

返回 `4`，与直接写：

```python
2 + 2
```

结果相同。动态语言允许程序在运行时构造并求值表达式，这正是“程序即数据”的直接体现。

## 8. 个人总结

这一章最重要的收获不是 Scheme 语法，而是解释器的分层结构。

一个解释器大致可以分成四层：

1. 词法分析：文本变成 token；
2. 语法分析：token 变成表达式树；
3. 求值：表达式树在环境中被解释；
4. 应用：过程与参数结合，必要时产生新的环境并递归求值。

其中最核心的是 `eval/apply` 互递归：

- eval 负责“这个表达式是什么，应该按什么规则处理”；
- apply 负责“这个过程拿到参数后应该怎样执行”。

异常机制则让解释器从“一次性脚本”变成“可持续交互系统”。REPL 不因一次输入错误而崩溃，是解释器可用性的重要组成部分。

如果要实现一个 Scheme 解释器，我会按以下顺序推进：

1. 实现 tokenizer；
2. 实现 `Pair`、`nil` 和 parser；
3. 支持 quote 和 dotted list；
4. 实现 `Frame` 与环境查找；
5. 实现自求值表达式和符号查找；
6. 实现特殊形式 `if`、`define`、`lambda`；
7. 实现 PrimitiveProcedure；
8. 实现 LambdaProcedure 的应用；
9. 用 `try/except` 完善 REPL；
10. 用递归、闭包和列表操作写测试程序。

理解本章后，再看 Python 会有一种“从魔法背后看机械结构”的感觉：名字不是凭空存在的，函数调用不是天然发生的，控制流也不是只靠语法关键字实现的；它们都由解释器的求值规则一步步构造出来。
