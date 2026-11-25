# Scheme 中的 Macros

## 1. 什么是宏

在 Scheme 中，**macro（宏）是一种在求值前对表达式本身进行变换的机制**。

普通函数调用时，Scheme 会先求值参数，再把结果传给函数：

```scheme
(define (my-if condition a b)
  (if condition a b))

(my-if #f 1 (/ 1 0))
```

这个调用会出错，因为 Scheme 会先求值：

```scheme
(/ 1 0)
```

即使 `condition` 是 `#f`，参数也会先被求值。

但 `if` 是特殊形式，它不会先求值所有参数，而是只求值需要的分支：

```scheme
(if #f 1 (/ 1 0))
; 不会执行 (/ 1 0)
```

宏的意义就是：**让用户也能定义这种“不是先求值参数，而是先变换代码结构”的新语法形式**。

## 2. 函数和宏的核心区别

### 函数

```scheme
(f x y)
```

求值过程：

1. 求值 `x`
2. 求值 `y`
3. 把结果作为参数传给 `f`

### 宏

```scheme
(macro-name x y)
```

求值过程大致是：

1. 把 `x` 和 `y` 当作表达式数据，不做求值
2. 按宏规则变换成新表达式
3. 再求值变换后的结果

所以：

- 函数操作的是**值**
- 宏操作的是**代码本身**

这也呼应了 Scheme/Lisp 的核心思想：**代码即数据**。

## 3. 基本语法：`define-syntax` 和 `syntax-rules`

Scheme 中常见写法是：

```scheme
(define-syntax macro-name
  (syntax-rules (pattern-variables)
    ((macro-name pattern ...)
     template)))
```

例如定义一个 `my-or`：

```scheme
(define-syntax my-or
  (syntax-rules ()
    ((my-or)
     #f)
    ((my-or x)
     x)
    ((my-or x rest ...)
     (let ((t x))
       (if t t (my-or rest ...))))))
```

使用：

```scheme
(my-or #f #f 3)
; 3

(my-or)
; #f
```

这个宏模拟了内置 `or` 的短路行为。

如果写成函数：

```scheme
(define (my-or-func a b)
  (if a a b))
```

那么调用：

```scheme
(my-or-func #f (/ 1 0))
```

会先求值 `(/ 1 0)`，然后报错。

而宏版本会先变换成类似：

```scheme
(let ((t #f))
  (if t t (/ 1 0)))
```

因为 `t` 是 `#f`，才会继续求值 `(/ 1 0)`。

这说明宏可以实现**延迟求值和短路求值**，这是普通函数做不到的。

## 4. 一个典型例子：定义 `unless`

Scheme 内置 `if`：

```scheme
(if condition then-part else-part)
```

我们可以定义一个更符合英语阅读习惯的 `unless`：

```scheme
(define-syntax unless
  (syntax-rules ()
    ((unless condition body ...)
     (if condition #f (begin body ...)))))
```

使用：

```scheme
(unless (> 1 2)
  (display "1 is not greater than 2"))
```

变换后的代码大致是：

```scheme
(if (> 1 2)
    #f
    (begin
      (display "1 is not greater than 2")))
```

注意：`body ...` 表示零个或多个表达式。

这个宏的意义是：

1. 只有条件为假时才执行；
2. 用户可以写多个表达式；
3. 不需要手动写 `begin`。

这本质上是在扩展语言本身。

## 5. 宏展开：编译期/求值前的代码变换

宏的关键机制叫**展开**。

假设有：

```scheme
(unless #t (display "hello"))
```

宏展开后变成：

```scheme
(if #t #f (begin (display "hello")))
```

再求值时，因为条件是 `#t`，所以不会执行 `display`。

宏展开发生在求值之前，因此宏可以：

- 改变参数是否被求值；
- 改变表达式的结构；
- 引入新的绑定；
- 生成重复代码；
- 隐藏控制流细节。

## 6. `...` 的含义

在 `syntax-rules` 中，`...` 表示“重复模式”。

例如：

```scheme
((unless condition body ...)
 (if condition #f (begin body ...)))
```

含义是：

- `body ...` 匹配零个或多个表达式；
- 模板里的 `body ...` 表示把这些表达式按顺序放回展开结果。

如果输入：

```scheme
(unless #f
  (display "a")
  (display "b"))
```

展开后：

```scheme
(if #f
    #f
    (begin
      (display "a")
      (display "b")))
```

所以 `...` 让宏可以处理可变数量的表达式。

## 7. 卫生宏

Scheme 的 `syntax-rules` 宏通常是**卫生宏**。

意思是：宏展开时自动避免变量名冲突。

例如：

```scheme
(define-syntax swap!
  (syntax-rules ()
    ((swap! a b)
     (let ((tmp a))
       (set! tmp b)
       (set! b tmp)))))
```

如果用户这样调用：

```scheme
(let ((tmp 1)
      (b 2))
  (swap! tmp b)
  (list tmp b))
```

直觉上可能会担心：宏内部也有 `tmp`，会不会和用户的 `tmp` 混在一起？

在卫生宏中不会。Scheme 会自动重命名宏内部的绑定，保证：

- 宏内部引入的 `tmp` 只属于宏展开后的代码；
- 不会意外捕获用户代码中的 `tmp`；
- 用户代码中的名字也不会意外被宏改变含义。

这就是“卫生”的意义。

## 8. 宏的意义

### 8.1 扩展语言本身

函数只能复用计算，宏可以复用语法结构。

例如：

```scheme
(while condition
  body ...)
```

Scheme 标准里可能没有 `while`，但可以用宏定义：

```scheme
(define-syntax while
  (syntax-rules ()
    ((while condition body ...)
     (let loop ()
       (when condition
         body ...
         (loop))))))
```

使用：

```scheme
(define i 0)
(while (< i 5)
  (display i)
  (set! i (+ i 1)))
```

宏让 Scheme 看起来像新增了控制结构。

这就是宏最重要的意义：**用户可以在语言之上构建语言特性**。

### 8.2 实现自定义控制流

很多控制形式必须依赖宏：

- `or` / `and` 的短路求值
- `when` / `unless`
- `while`
- `for`
- `cond`
- 惰性求值
- 状态机 DSL
- 领域专用语言

这些都涉及“不是先求值所有参数”的行为，普通函数很难直接表达。

### 8.3 减少样板代码

例如没有宏时，写短路 `or` 可能需要闭包：

```scheme
(or-thunk (lambda () x)
          (lambda () y))
```

因为只有 thunk 才能延迟求值。

但有宏后，用户仍然可以写自然语法：

```scheme
(my-or x y)
```

宏在幕后生成正确的延迟结构。

因此宏可以同时提供：

- 自然语法
- 延迟求值
- 高性能展开
- 语义控制

### 8.4 体现“代码即数据”

宏之所以可能，是因为 Scheme 程序本身可以用列表表示。

例如：

```scheme
(+ 1 2)
```

既是一个待求值的表达式，也可以看作列表：

```scheme
'(+ 1 2)
```

宏正是利用这一点：

1. 把用户代码当作数据结构读取；
2. 对这个数据结构做变换；
3. 生成新的代码结构；
4. 再交给解释器或编译器求值。

这直接体现了第 3 章的核心思想：**解释器处理的表达式，本身就是数据**。

## 9. 宏的适用场景

适合用宏的情况：

| 场景 | 原因 |
|---|---|
| 定义新的控制结构 | 需要改变求值顺序或短路行为 |
| 定义新的语法形式 | 函数无法改变调用语法 |
| 自动生成重复结构 | 宏可以在展开期生成代码 |
| 构建领域专用语言 | DSL 往往需要专属语法和求值规则 |
| 需要避免参数提前求值 | 例如惰性求值、短路逻辑 |

不适合用宏的情况：

| 场景 | 更好的做法 |
|---|---|
| 只是封装纯计算 | 用函数 |
| 只是把代码移动一下 | 用函数或局部变量 |
| 逻辑复杂且不需要语法变换 | 用函数 |
| 希望运行时动态决定行为 | 用高阶函数 |
| 需要普通调试体验 | 宏有时更难调试 |

一个常用判断标准是：

> 如果参数可以先全部求值，再传给过程，就用函数；  
> 如果必须在求值前变换代码，才用宏。

## 10. 宏与解释器的关系

在解释器中，宏处理通常发生在 `scheme_eval` 之前或之初：

```text
输入表达式
  -> 识别宏
  -> macro expand
  -> 得到新的表达式
  -> scheme_eval
```

伪代码：

```scheme
(define (eval expr env)
  (let ((expanded (macro-expand expr)))
    (if (equal? expanded expr)
        (eval-original expr env)
        (eval expanded env))))
```

也就是说，宏层可以看作解释器前面的一个转换层：

```text
source expression
  -> macro expansion
  -> core Scheme expression
  -> eval/apply
```

这和第 3 章的解释器结构是自然衔接的。

## 11. 总结

Scheme 宏的本质是：

> **在求值前，把一种表达式形式变换成另一种表达式形式。**

它的意义在于：

1. **操作代码，而不是操作值**
2. **实现短路求值和自定义控制流**
3. **让用户扩展语言语法**
4. **减少样板代码和闭包包装**
5. **直接利用“代码即数据”的思想**
6. **把解释器前面的求值阶段变成了可编程阶段**

一句话概括：

> 函数让你复用计算；宏让你复用语法和控制结构。  
> 函数把值变成新的值；宏把代码变成新的代码。

## 12. 案例：Multiple Assignment

### 12.1 题目

在 Scheme 中，宏过程返回的表达式会在调用宏的环境中求值。因此，宏可以返回一个 `define` 表达式，并让它影响宏被调用时的环境。

这与普通 Scheme 过程不同：普通过程内部的 `define` 只会影响该过程的局部 frame。

Python 可以在一行中绑定两个名字：

```python
x, y = 1 + 1, 3
x, y = y, x
```

执行后：

```python
x  # 3
y  # 2
```

现在要求实现 `assign` Scheme 宏，它接收两个符号 `sym1`、`sym2` 和两个表达式 `expr1`、`expr2`，并在宏调用的环境中：

- 把 `sym1` 绑定到 `expr1` 的值；
- 把 `sym2` 绑定到 `expr2` 的值。

示例：

```scheme
scm> (assign x y (+ 1 1) 3)
scm> (assign x y y x)
scm> x
3
scm> y
2
```

关键要求是：`expr2` 必须在 `sym1` 被修改之前求值。

题目还假设 `expr1` 和 `expr2` 没有副作用，因此不会包含 `define` 或 `assign`。

### 12.2 解法

```scheme
(define-macro (assign sym1 sym2 expr1 expr2)
  `(begin
     (define ,sym1 ,expr1)
     (define ,sym2 ',(eval expr2))))
```

测试：

```scheme
(assign x y (+ 1 1) 3)
(assign x y y x)
(expect x 3)
(expect y 2)
```

额外测试：

```scheme
(define z 'x)
(assign v w 2 z)
(assign v w w v)
(expect v x)
(expect w 2)
```

### 12.3 为什么普通 define 不够

如果第二行写成普通的：

```scheme
(define ,sym2 ,expr2)
```

那么：

```scheme
(assign x y y x)
```

会展开成：

```scheme
(begin
  (define x y)
  (define y x))
```

假设交换前：

```text
x = 2
y = 3
```

执行过程是：

```text
(define x y)  ; x 变成 3
(define y x)  ; 此时 x 已经是 3，所以 y 也变成 3
```

最终：

```text
x = 3
y = 3
```

原来的 `x = 2` 已经被覆盖，交换失败。

问题在于，第二个 `define` 的右值 `x` 是在第一个 `define` 执行完之后才被求值的。

### 12.4 为什么使用 `(eval expr2)`

解法中的这一部分：

```scheme
',(eval expr2)
```

会在宏展开时先求值 `expr2`。

对于：

```scheme
(assign x y y x)
```

宏展开时环境仍然是：

```text
x = 2
y = 3
```

因此：

```scheme
(eval expr2)
```

相当于：

```scheme
(eval 'x)
```

得到旧值：

```text
2
```

于是宏展开结果类似：

```scheme
(begin
  (define x y)
  (define y '2))
```

执行：

```text
(define x y)  ; x 变成 3
(define y '2) ; y 使用提前保存的旧 x 值 2
```

结果：

```text
x = 3
y = 2
```

交换成功。

因此，第二行与第一行不同的根本原因是：

- 第一行的 `expr1` 可以留给第一个 `define` 在运行时求值，因为它会在修改 `sym1` 之前被求值；
- 第二行的 `expr2` 如果不提前求值，就会在 `sym1` 已被修改后才求值，所以必须先捕获旧值。

### 12.5 为什么还要加 `quote`

`(eval expr2)` 返回的可能不是数字，而是符号、列表或其他 Scheme 值。

例如：

```scheme
(define z 'x)
```

此时：

```scheme
z
```

的值是符号 `x`，而不是 `x` 当前绑定的值。

执行：

```scheme
(assign v w 2 z)
```

宏展开时：

```scheme
(eval z)
```

得到符号：

```text
x
```

如果只写：

```scheme
(define ,sym2 ,(eval expr2))
```

会生成：

```scheme
(define w x)
```

这会把 `w` 绑定到变量 `x` 的值，而不是符号 `x` 本身。

如果写成：

```scheme
(define ,sym2 ',(eval expr2))
```

则会生成：

```scheme
(define w 'x)
```

这样 `w` 才绑定到符号 `x`。

一般地，`quote` 的作用是：

> 把已经计算出来的值作为数据插入生成的代码，避免它之后又被当作表达式求值。

对于数字和布尔值，这种区别可能看不出来；对于符号和列表，差异非常明显。

例如，如果 `(eval expr2)` 得到列表 `(1 2)`：

- 不加 `quote`：生成的代码是 `(define w (1 2))`，会尝试把 `1` 当作操作符调用，从而报错；
- 加 `quote`：生成的代码是 `(define w '(1 2))`，会正确绑定到列表。

### 12.6 一句话 presentation

> 第二行必须写成 `',(eval expr2)`，因为要在返回的代码真正执行、`sym1` 被改变之前先求出并保存 `expr2` 的旧值，同时用 `quote` 保证这个值作为数据插入，而不是之后被再次求值。
