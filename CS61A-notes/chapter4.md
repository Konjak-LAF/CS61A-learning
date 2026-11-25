# Composing Programs 第四章学习笔记：声明式编程、SQL 与数据系统

本笔记阅读范围为 4.3 到 4.8。内容重点放在 SQL、关系数据库、查询执行、分布式数据处理与并发控制；4.4 和 4.5 中专门为教材设计的 `logic` 语言只保留与数据库查询相关的思想，不展开其解释器实现。

## 1. 本章主线

第四章讨论的核心问题是：程序不一定需要一步步描述“如何计算”，也可以只描述“想要什么结果”。

这种风格称为声明式编程。SQL 是最典型的例子：

```sql
select name, latitude
from cities
where latitude > 43;
```

这段代码没有说明数据库应该先扫描哪张表、使用哪个索引、如何排序或如何并行。它只描述结果应满足的条件。真正决定执行过程的是数据库系统中的查询解释器和查询优化器。

因此本章可以沿着以下路线理解：

1. 数据库用表保存记录，用查询语言检索和变换数据。
2. SQL 是声明式语言，核心操作包括投影、过滤、连接、聚合和排序。
3. SQL 解释器把查询变成某种执行过程，查询计划决定效率。
4. 递归查询可以处理层级与图结构数据。
5. 逻辑编程提供了另一种声明式查询模型，但它与 SQL 的工程定位不同。
6. 当数据量超过单机能力时，需要分布式存储、分布式计算和并行执行。
7. 并行执行又带来共享状态、锁、死锁和事务隔离等问题。

## 2. 数据库与关系模型基础

数据库由两部分组成：

- 数据存储：保存实际的数据值。
- 查询接口：提供检索和变换数据的方法。

数据库中的每个值称为一条记录。结构相似的记录被组织成表。对表进行检索和变换的语句称为查询。

关系模型中的基本术语如下：

| 术语 | 含义 |
|---|---|
| 表 | 一组结构相同的记录，也称关系 |
| 行 | 一条记录 |
| 列 | 一个有名字和类型的字段 |
| 模式 | 表的列名、类型及约束的整体定义 |
| 查询 | 从表中检索或计算数据的语句 |
| 结果表 | 查询产生的新表，可以继续被其他查询使用 |

例如：

| latitude | longitude | name |
|---:|---:|---|
| 38 | 122 | Berkeley |
| 42 | 71 | Cambridge |
| 45 | 93 | Minneapolis |

这张表的每一行表示一个城市，每一列表示城市的一个属性。

这里有一个重要观点：查询的结果本身也是一张表。因此 SQL 查询可以嵌套、组合、命名，并被后续查询继续使用。

## 3. 创建表与基本 SELECT

教材使用 SQLite 的一个子集。一条简单查询可以由 `select` 直接构造一行：

```sql
select 38 as latitude, 122 as longitude, "Berkeley" as name;
```

`as` 给结果列命名。`union` 可以纵向合并两张结构相同的表：

```sql
select 38 as latitude, 122 as longitude, "Berkeley" as name union
select 42,             71,               "Cambridge"        union
select 45,             93,               "Minneapolis";
```

用 `create table ... as select ...` 可以给查询结果命名：

```sql
create table cities as
  select 38 as latitude, 122 as longitude, "Berkeley" as name union
  select 42,             71,               "Cambridge"        union
  select 45,             93,               "Minneapolis";
```

有了表名后，就可以在 `from` 子句中使用它：

```sql
select * from cities;
```

`select *` 表示选择所有列。

### 3.1 投影、计算列与别名

基本形式是：

```sql
select [column description]
from [existing table name];
```

列描述中可以使用表达式：

```sql
select name, 60 * abs(latitude - 38) as distance
from cities;
```

这里的 `name` 和 `latitude` 都表示当前行对应列的值。`as distance` 给计算列命名，便于后续查询继续引用。

从关系代数角度看，这一步同时包含：

- 对每一行求列表达式的值。
- 选择结果中要保留的列。
- 给结果列命名。

### 3.2 WHERE：过滤行

`where` 子句只保留条件为真的行：

```sql
select name
from cities
where latitude > 43;
```

`where` 是在聚合之前过滤单行记录。这一点和后面的 `having` 不同。

### 3.3 ORDER BY：排序

`order by` 根据表达式对结果行排序：

```sql
select distance, name
from distances
order by -distance;
```

排序表达式可以包含计算，也可以升序或降序。教材示例通过 `-distance` 实现降序。

### 3.4 SQL 的逻辑执行顺序

书写顺序通常是：

```text
SELECT -> FROM -> WHERE -> GROUP BY -> HAVING -> ORDER BY
```

但理解查询时，更重要的是逻辑处理顺序：

```text
FROM / JOIN
  -> WHERE
  -> GROUP BY
  -> HAVING
  -> SELECT
  -> DISTINCT
  -> ORDER BY
  -> LIMIT
```

数据库实际执行不一定是这个顺序，因为查询优化器会重排操作。但逻辑顺序能解释很多规则，例如：

- `where` 不能直接使用聚合结果。
- `having` 可以在分组后过滤组。
- `order by` 可以使用结果列，也可以使用输入列。
- `select` 中的别名在某些数据库中不能直接用于同一个 `where` 子句。

## 4. JOIN：连接多张表

实际数据库通常有很多张表，查询需要从不同表中组合信息。

例如，城市位置表和温度表分别存储：

```sql
create table temps as
  select "Berkeley" as city, 68 as temp union
  select "Chicago",          59          union
  select "Minneapolis",      55;
```

### 4.1 笛卡尔积

教材重点介绍的一种连接方式是在 `from` 中用逗号列出多张表：

```sql
select *
from cities, temps;
```

如果左表有 `m` 行，右表有 `n` 行，结果会有 `m * n` 行。这就是笛卡尔积。

笛卡尔积本身通常没有业务意义。真正的连接一般会配合 `where` 指定匹配条件：

```sql
select name, latitude, temp
from cities, temps
where name = city;
```

这表示只保留 `cities.name` 与 `temps.city` 相等的组合。

### 4.2 表别名与点表达式

当两张表有同名列，或一张表需要与自身连接时，必须区分列来自哪张表：

```sql
select a.city, b.city, a.temp - b.temp
from temps as a, temps as b
where a.city < b.city;
```

`a` 和 `b` 是表别名。`a.city` 表示 `a` 表中的 `city` 列。

使用 `<` 而不是 `!=` 可以避免同一对城市出现两次。

### 4.3 现代 SQL 的 JOIN 写法

教材为简化解释器，主要使用“逗号连接加 WHERE”。实际数据库更常用显式连接：

```sql
select cities.name, cities.latitude, temps.temp
from cities
join temps
  on cities.name = temps.city;
```

常见连接类型如下：

| 类型 | 含义 |
|---|---|
| `inner join` | 只保留两边匹配成功的行 |
| `left join` | 保留左表所有行，右表无匹配时补 `NULL` |
| `right join` | 保留右表所有行 |
| `full outer join` | 保留两边所有行 |
| `cross join` | 笛卡尔积 |

教材中的“逗号连接 + where”本质上等价于内连接。

### 4.4 JOIN 与 UNION 的区别

`join` 和 `union` 都组合表，但方向不同：

- `join` 横向组合列，按行之间的关系匹配。
- `union` 纵向组合行，要求列数和类型兼容。

可以把它们粗略理解为：

```text
JOIN   ：把更多列拼到一行上
UNION  ：把更多行追加到表下面
```

#### 补充：JOIN

**核心模型**

理解 `JOIN` 的关键不是“两行如何配成一对”，而是：

1. 先根据 `FROM` 和 `JOIN` 构造候选行组合。
2. 再由 `ON` 判断哪些组合有意义。
3. 最后由连接类型决定：没配上的行是否保留。

把 `JOIN` 读成“按条件扩展表”会更自然：

```sql
FROM dogs AS d
JOIN sizes AS s ON d.height > s.min AND d.height <= s.max
```

可以先理解为：对每一条狗，尝试匹配所有尺寸区间；匹配成功的组合留下，形成一张同时包含狗和尺寸列的新表。

**基本语法**

```sql
SELECT columns
FROM left_table AS l
JOIN right_table AS r
  ON l.key = r.key
WHERE condition;
```

`JOIN` 默认就是 `INNER JOIN`。链式连接时，前一个 `JOIN` 的结果会成为下一个 `JOIN` 的左表：

```
FROM a
JOIN b ON a.id = b.id
JOIN c ON b.id = c.id
```

旧式写法也可以表示内连接：

```sql
FROM a, b
WHERE a.id = b.id
```

它和 `JOIN ... ON` 在内连接中通常等价，但显式 `JOIN` 更容易区分：

- `ON` 写表和表之间的连接条件。
- `WHERE` 写对连接结果的普通筛选条件。

**常见 JOIN 类型**

- `INNER JOIN`：只保留双方匹配成功的行，最常用。
- `LEFT JOIN`：保留左表所有行；右表没匹配时，右表列填 `NULL`。
- `RIGHT JOIN`：保留右表所有行，逻辑上和左右互换的 `LEFT JOIN` 对称。
- `FULL OUTER JOIN`：左右表所有行都保留，没匹配的一侧填 `NULL`。
- `CROSS JOIN`：不写匹配条件，产生笛卡尔积，左表每行和右表每行都组合一次。
- `SELF JOIN`：不是特殊关键字，只是同一张表使用两个别名连接自己。
- `NON-EQUI JOIN`：连接条件不是 `=`，而是 `>`、`<`、`BETWEEN` 等范围条件。

例如保留所有狗，包括没有父母记录的狗：

```sql
SELECT d.name, p.parent
FROM dogs AS d
LEFT JOIN parents AS p
  ON p.child = d.name;
```

没有匹配到的狗仍然出现，`p.parent` 为 `NULL`。

**HW10 中的四种模式**

等值连接：

```sql
SELECT p.child
FROM parents AS p
JOIN dogs AS d ON d.name = p.parent;
```

连接条件是 `p.parent = d.name`，这是最常见的外键匹配。

非等值连接：

```sql
SELECT d.name, s.size
FROM dogs AS d
JOIN sizes AS s
  ON d.height > s.min AND d.height <= s.max;
```

这里不是找相同值，而是判断身高位于哪个区间。

自连接：

```sql
SELECT a.child AS first, b.child AS second
FROM parents AS a
JOIN parents AS b
  ON a.parent = b.parent AND a.child < b.child;
```

同一张 `parents` 表出现两次，因此必须使用不同别名。`a.child < b.child` 既排除自己和自己配对，也排除重复的反向组合。

多表连续连接：

```sql
FROM siblings AS s
JOIN size_of_dogs AS d1 ON d1.name = s.first
JOIN size_of_dogs AS d2 ON d2.name = s.second
                        AND d2.size = d1.size
```

这里把 `size_of_dogs` 连接了两次。一次查第一个兄弟姐妹的尺寸，另一次查第二个的尺寸，最后要求两者相等。

**ON 与 WHERE 的区别**

内连接中，连接条件和普通筛选条件常常可以互换；外连接中不能随便互换：

```sql
A LEFT JOIN B
  ON A.id = B.a_id AND B.active = 1
```

这表示先尝试用 `active = 1` 的 B 行匹配 A。A 即使没有匹配，也会保留，B 的列填 `NULL`。

```sql
A LEFT JOIN B
  ON A.id = B.a_id
WHERE B.active = 1
```

这里先保留所有 A，再筛掉 `B.active` 为 `NULL` 的行。结果通常会退化成内连接。

**常见陷阱**

- 忘记写 `ON` 会形成笛卡尔积；有些数据库允许 `JOIN B` 不接条件，效果接近交叉连接。
- 多个表有同名列时必须用 `别名.列名` 限定。
- `NULL` 不会通过 `=` 匹配另一个 `NULL`。
- 一条左表行匹配多条右表行时，结果会重复左表信息，这不是错误，而是 JOIN 的基数行为。
- `NATURAL JOIN` 和 `USING` 更短，但依赖列名，表结构变化后容易出错；学习阶段优先写显式 `ON`。
- 外层查询的 `WHERE` 可能消除 `LEFT JOIN` 本来想保留的 `NULL` 行。

一句话记忆：`INNER JOIN` 是“只留匹配”，`LEFT JOIN` 是“左边全留”，`CROSS JOIN` 是“全部两两组合”，`SELF JOIN` 是“一张表连接自己”，`NON-EQUI JOIN` 是“用范围而不是等号匹配”。

## 5. 聚合与分组

前面的 `select` 主要处理单行。聚合函数则把多行合并成一个值。

常见函数包括：

```sql
max(column)
min(column)
count(column)
sum(column)
```

例如：

```sql
select max(legs) from animals;
select sum(weight) from animals;
select min(legs), max(weight)
from animals
where name <> "t-rex";
```

`where` 先过滤行，聚合函数只作用于过滤后的行。

### 5.1 COUNT 与 DISTINCT

```sql
select count(legs) from animals;
select count(*) from animals;
select count(distinct legs) from animals;
```

三者分别表示：

- 统计 `legs` 列的取值数量。
- 统计结果行数。
- 统计 `legs` 列的不同取值数量。

在标准 SQL 中，`count(column)` 通常忽略 `NULL`，而 `count(*)` 统计所有行。教材的简化数据集没有 `NULL`，但真实数据库必须注意这一区别。

### 5.2 GROUP BY

`group by` 把行划分为若干组，每组独立计算聚合：

```sql
select legs, max(weight)
from animals
group by legs;
```

这回答的是“每种腿数对应的最大体重是多少”，而不是“整张表的最大体重是多少”。

如果有多个分组表达式，则按它们的唯一组合分组：

```sql
select max(name)
from animals
group by legs, weight;
```

### 5.3 HAVING

`having` 用于过滤分组后的结果：

```sql
select weight
from animals
group by weight
having count(*) > 1;
```

这里不能把 `count(*) > 1` 写在 `where` 中，因为 `where` 执行时还没有分组，聚合结果尚不存在。

规则可以概括为：

| 子句 | 作用对象 | 是否可使用聚合 |
|---|---|---|
| `where` | 单行 | 不可以 |
| `having` | 分组 | 可以 |

### 5.4 分组查询的陷阱

如果 `select` 中既有聚合列，又有普通列，普通列的取值必须有明确含义。

例如：

```sql
select name, max(weight)
from animals;
```

SQLite 可能根据最大体重返回对应的 `name`，但很多数据库不允许这种写法，或者结果不可预测。

更稳妥的数据库实践是：

- 只选择分组列和聚合列。
- 或者在子查询中先计算最大值，再连接回原表找到对应行。

例如：

```sql
select a.name, a.weight
from animals as a
join (
  select max(weight) as max_weight
  from animals
) as m
  on a.weight = m.max_weight;
```

这比依赖数据库对非聚合列的任意选择更清晰。

## 6. SQL 解释器与查询计划

教材实现了一个小型 SQL 解释器，用来展示声明式语言的内部结构。

### 6.1 表的表示

每一行可以用 Python 的 `namedtuple` 表示：

```python
from collections import namedtuple

CitiesRow = namedtuple("Row", ["latitude", "longitude", "name"])

cities = [
    CitiesRow(38, 122, "Berkeley"),
    CitiesRow(42, 71, "Cambridge"),
    CitiesRow(45, 93, "Minneapolis"),
]
```

每张表是一个行序列，每一行是带列名的记录。

### 6.2 Select 的执行

解释器中的 `Select.execute` 大致执行：

```text
join
  -> filter
  -> sort
  -> map/project
```

对应关系为：

| SQL 子句 | 解释器操作 |
|---|---|
| `from` | 生成组合后的行 |
| `where` | 过滤行 |
| `order by` | 排序 |
| `select` | 把输入行映射为输出行 |

教材的 `join` 使用 `itertools.product` 生成所有组合：

```python
from itertools import product

joined_rows = product(*[env[name] for name in names])
```

然后通过 `where` 过滤出真正匹配的组合。

### 6.3 查询计划

声明式语言只描述结果，不规定实现。同一个 SQL 查询通常有多种执行方式，这些可选方案称为查询计划。

例如：

```sql
select cities.name, distance, longitude
from cities, distances
where cities.name = distances.name;
```

一种低效做法是先生成 `cities` 与 `distances` 的完整笛卡尔积，再逐行过滤。

一种更高效做法是：

1. 分别按 `name` 排序。
2. 在线性扫描中匹配同名行。
3. 只输出匹配组合。

数据库查询优化器会考虑：

- 是否使用索引。
- 使用嵌套循环连接、排序合并连接还是哈希连接。
- 哪个表先过滤。
- 聚合是否可以提前完成。
- 是否可以并行扫描、并行连接和并行聚合。

这正是声明式编程的价值：用户表达逻辑需求，数据库负责选择物理执行方案。

## 7. WITH 与递归查询

`with` 子句可以定义并命名临时表：

```sql
with
  states(city, state) as (
    select "Berkeley", "California" union
    select "Boston", "Massachusetts" union
    select "Cambridge", "Massachusetts" union
    select "Chicago", "Illinois" union
    select "Pasadena", "California"
  )
select a.city, b.city, a.state
from states as a, states as b
where a.state = b.state and a.city < b.city;
```

这称为公共表表达式，常缩写为 CTE。它让复杂查询可以分层表达。

### 7.1 递归 CTE

SQL 查询也可以递归。一般由两部分组成：

1. 基础情况：产生第一行或第一批行。
2. 递归情况：从已有结果继续产生新行。

教材中的整数序列：

```sql
with
  ints(n) as (
    select 5 union
    select n + 1
    from ints
    where n < 15
  )
select n, n * n
from ints
where n % 2 = 1;
```

执行过程：

```text
5
  -> 6
  -> 7
  -> ...
  -> 15
  -> 停止，因为 n < 15 不再成立
```

标准 SQL 通常写作：

```sql
with recursive ints(n) as (
  select 5
  union all
  select n + 1
  from ints
  where n < 15
)
select n from ints;
```

递归 CTE 很适合处理：

- 组织架构树。
- 目录和子目录。
- 图上的可达路径。
- 依赖关系。
- 时间或状态序列。
- 供应链、家谱和路线规划。

### 7.2 递归终止

递归查询必须保证会停止。常见方法有：

- 用 `where` 限制递归深度或数值范围。
- 确保每轮产生的结果满足终止条件。
- 使用 `union` 去重，避免重复行导致无限循环。
- 使用 `union all` 时尤其要谨慎，因为重复行不会被消除。

教材用 `union` 让结果自然去重。数据库工程中需要同时关注终止性、性能和不必要的重复计算。

## 8. 逻辑编程的简要定位

4.4 和 4.5 引入了教材自定义的 `logic` 语言，基于 Prolog 和逻辑推理思想。它不是 SQL，也不是实际工程中常用的数据库接口。

它与 SQL 的主要相似点是：

| 逻辑编程概念 | SQL 中的对应概念 |
|---|---|
| 事实 | 表中的行 |
| 关系 | 表或谓词 |
| 查询 | `select` 查询 |
| 多条件查询 | 多表连接 |
| 递归事实 | 递归 CTE 或图遍历 |
| 模式匹配 | 按列值匹配行 |
| 推理搜索 | 查询求解与执行计划的一部分 |

可以把它理解为另一种声明式查询风格：

```text
SQL：从表中检索并计算满足条件的结果
Logic：根据事实和规则推导出满足查询的结论
```

SQL 的工作重点是可靠地管理、查询和更新数据；逻辑编程更偏向通用推理、规则系统和符号计算。对于数据库学习来说，掌握它们在“声明结果而非过程”上的共同点即可，不必深入 `logic` 解释器细节。

## 9. 分布式计算与分布式数据库

单机数据库受限于单台机器的 CPU、内存、磁盘和网络。数据规模继续增长时，就需要把数据和计算分布到多台机器。

分布式系统的基本特征是：

- 多台计算机相互连接但彼此独立。
- 它们不能直接共享内存。
- 通信必须通过网络消息完成。
- 消息需要协议规定编码和解码方式。

TCP/IP 提供了基础通信能力：

- IP 负责把数据包转发到目标地址。
- IP 不保证顺序、不保证不丢失、不保证不重复。
- TCP 在 IP 之上提供可靠、有序的字节流。
- TCP 通过重传、去重和排序实现可靠性，但会增加延迟。

### 9.1 客户端与服务器

数据库系统通常采用客户端服务器架构：

- 数据库服务器管理数据、执行 SQL、控制事务和并发。
- 客户端发送查询、接收结果。
- 客户端不需要知道数据如何存储、如何索引、如何并行执行。

这种架构的优点是模块化，但服务器可能成为瓶颈和单点故障。

### 9.2 分布式数据库中的关键问题

把数据库分布到多台机器后，会面临：

| 问题 | 含义 |
|---|---|
| 分区 | 把数据按行或按列拆分到不同节点 |
| 分片 | 分区的一种常见形式 |
| 复制 | 在多个节点保存副本，提高可用性和读取吞吐 |
| 一致性 | 多个副本之间如何保持一致 |
| 故障恢复 | 节点失效后如何继续服务并恢复数据 |
| 协调 | 多个节点如何共同完成事务和查询 |

实际分布式数据库需要在一致性、可用性和延迟之间权衡。这个问题与 CAP 理论和分布式事务密切相关。

## 10. MapReduce 与分布式数据处理

当数据集无法由一台机器处理时，可以将数据分布到多台机器，每台机器处理一部分，再汇总结果。

MapReduce 把这种计算抽象为三步：

1. Map：对每条输入生成零个或多个键值对。
2. Group/Sort：按 key 分组，使相同 key 的值可以一起处理。
3. Reduce：对每个 key 的值集合进行汇总，产生最终结果。

教材中的元音计数示例：

```python
def count_vowels(line):
    for vowel in "aeiou":
        count = line.count(vowel)
        if count > 0:
            emit(vowel, count)
```

对应的 reduce 就是求和：

```python
for key, value_iterator in values_by_key(sys.stdin):
    emit(key, sum(value_iterator))
```

从数据库角度可以写成类似：

```sql
select vowel, sum(count)
from vowel_counts
group by vowel;
```

因此可以这样理解：

```text
map     -> 产生分组前的中间记录
shuffle -> 按 key 重新分发并分组
reduce  -> 对每组做聚合
```

### 10.1 为什么要求纯函数

MapReduce 要求 map 和 reduce 尽量是纯函数。纯函数没有共享可变状态，因此：

- 不同输入可以任意顺序计算。
- 相同任务可以重试。
- 失败任务可以在其他机器上重新执行。
- 计算可以并行和重新编排。

这正是函数式编程在大数据系统中的一个重要应用。

### 10.2 本地实现与分布式实现

本地 MapReduce 可以用 Unix 管道表达：

```text
cat input | ./mapper.py | sort | ./reducer.py
```

这里：

- `mapper.py` 对每条输入产生若干键值对。
- `sort` 充当分组阶段，让相同 key 相邻。
- `reducer.py` 对每组值汇总。

Hadoop 等系统把同一模型扩展到集群，并提供：

- 并行执行。
- 机器和任务失败后的重算。
- 中间数据传输和分组。
- 进度监控。
- 分布式文件系统。

MapReduce 与数据库的连接非常紧密。很多 SQL 查询都可以分解为：

```text
过滤 -> 映射 -> 按 key 分区 -> 排序或哈希分组 -> 聚合 -> 合并结果
```

区别在于：

- 传统数据库更强调事务、低延迟和精确查询。
- MapReduce 更强调大规模批处理、容错和高吞吐。
- 现代 SQL 引擎往往融合两者，采用分布式执行、列式存储和向量化计算。

## 11. 并行计算、并发控制与数据库

并行计算不仅用于大数据，也贯穿数据库内部执行。数据库系统需要利用多核 CPU 和多台机器来并行执行查询。

### 11.1 线程与进程

Python 中主要有两种并行方式：

| 方式 | 特点 |
|---|---|
| 线程 | 共享同一解释器内的数据，适合 I/O 并发 |
| 多进程 | 各自有独立内存，可真正利用多核 |

线程共享数据，通信方便，但容易产生竞态条件。进程隔离更安全，但共享状态必须通过消息传递。

### 11.2 竞态条件

经典例子是两个线程同时执行：

```python
count = counter[0]
counter[0] = count + 1
```

自增看起来是一条语句，实际包含：

```text
读取 -> 加一 -> 写回
```

如果两个线程都读取到旧值，再分别写回，就会丢失一次更新。这就是竞态条件。

数据库中的并发问题与此类似：

- 丢失更新。
- 脏读。
- 不可重复读。
- 幻读。

数据库通过事务和隔离级别解决这些问题。

### 11.3 同步机制

常见同步手段包括：

| 机制 | 作用 |
|---|---|
| 同步数据结构 | 用现成的线程安全队列等避免手工加锁 |
| 锁 | 保证同一时间只有一组操作访问共享数据 |
| 屏障 | 把计算划分为多个阶段 |
| 消息传递 | 避免共享内存，通过发送数据协调 |

数据库中的对应机制包括：

- 行锁、表锁和意向锁。
- 多版本并发控制，即 MVCC。
- 两阶段锁。
- 事务日志和写前日志。
- 死锁检测与回滚。

### 11.4 同步的常见错误

**欠同步**：本应一起原子执行的多个操作被拆开，导致其他线程插入并破坏不变量。

**过度同步**：锁定范围过大，使本可并行的操作串行化，降低吞吐。

**死锁**：多个线程或事务互相等待对方持有的资源，形成循环等待。

数据库系统常见的死锁处理方式是检测循环等待并回滚其中一个事务。应用层则需要重试事务或统一加锁顺序。

## 12. 数据库补充知识

以下概念没有在教材 4.3 中系统展开，但对理解真实数据库非常重要。

### 12.1 键

| 概念 | 含义 |
|---|---|
| 主键 | 唯一标识一行，通常不允许为空 |
| 候选键 | 可以作为主键的候选列或列组合 |
| 外键 | 指向另一张表的主键或候选键，建立表间引用 |
| 复合键 | 由多列共同组成的主键或唯一键 |

外键与 JOIN 的关系：

```text
外键负责表达引用关系
JOIN 负责在查询时把相关行连接起来
```

### 12.2 索引

索引是额外的数据结构，用于加速查找、连接和排序。

常见索引结构包括：

- B 树和 B+ 树。
- 哈希索引。
- 位图索引。
- 全文索引。

索引能提高查询速度，但会降低写入速度并占用额外空间。因此数据库设计中需要根据查询模式建立索引，而不是给每一列都建索引。

### 12.3 事务与 ACID

事务是一组应当整体成功或整体失败的操作。

ACID 分别表示：

| 属性 | 含义 |
|---|---|
| Atomicity | 原子性，事务中的操作要么全部成功，要么全部失败 |
| Consistency | 一致性，事务前后数据库满足约束 |
| Isolation | 隔离性，并发事务之间互不干扰 |
| Durability | 持久性，提交后的结果不会因故障丢失 |

SQL 中的典型事务写法：

```sql
begin;
update accounts set balance = balance - 100 where id = 1;
update accounts set balance = balance + 100 where id = 2;
commit;
```

如果中途失败，则回滚：

```sql
rollback;
```

### 12.4 NULL 与三值逻辑

SQL 中 `NULL` 表示未知或缺失，不表示 0，也不表示空字符串。

比较 `NULL` 的结果通常不是真或假，而是未知：

```sql
select * from users where email = null;  -- 通常错误
```

应使用：

```sql
select * from users where email is null;
```

聚合函数和 `count` 对 `NULL` 的处理也需要特别注意。

### 12.5 视图与 CTE

视图是一个被命名并保存的查询：

```sql
create view active_users as
select * from users where active = true;
```

CTE 则通常只在一段查询中使用：

```sql
with active_users as (
  select * from users where active = true
)
select count(*) from active_users;
```

二者都能提高查询的模块化程度。区别是视图可以长期存储，CTE 通常属于单条查询。

## 13. SQL 速查

| 需求 | 基本写法 |
|---|---|
| 选择所有列 | `select * from t;` |
| 选择列并改名 | `select a as x from t;` |
| 过滤行 | `select * from t where p;` |
| 排序 | `select * from t order by a;` |
| 去重 | `select distinct a from t;` |
| 分组聚合 | `select a, count(*) from t group by a;` |
| 过滤分组 | `... group by a having count(*) > 1;` |
| 内连接 | `select * from a join b on a.id = b.id;` |
| 左连接 | `select * from a left join b on a.id = b.id;` |
| 自连接 | `select * from t as a, t as b where ...;` |
| 合并行 | `select ... union select ...;` |
| 临时表 | `with t as (select ...) ...;` |
| 递归查询 | `with recursive t as (base union all step) ...;` |

## 14. 总结

第四章最重要的数据库思想可以概括为四句话：

1. SQL 是声明式语言，用户描述结果，数据库负责决定执行过程。
2. 表是记录的关系集合，查询结果也是表，因此查询可以层层组合。
3. JOIN、GROUP BY、HAVING 和递归 CTE 是关系数据处理的核心工具。
4. 查询计划、索引、事务、并发控制和分布式执行决定了 SQL 在真实系统中的效率与可靠性。

教材中的自定义 `logic` 语言展示的是逻辑推理和模式匹配如何实现声明式查询，但它主要是教学模型。学习数据库时，真正需要优先掌握的是：

```text
关系模型
  -> SQL 查询语义
  -> JOIN 与聚合
  -> 索引与查询计划
  -> 事务与并发控制
  -> 分区、复制与分布式执行
```

这样就能把第四章从“SQL 语法入门”提升为对数据库系统工作方式的理解。
