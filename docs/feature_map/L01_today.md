下面我按 **“用户界面 → 状态管理 → 表单组件 → 领域模型 → Repository → DataSource → Drift/SQLite”** 的顺序，把 Today 模块讲清楚。

你可以把 Today 模块理解成 Rebirth 的第一个完整业务闭环：

```text
用户填写 Today 页面
        ↓
TodayForm 收集输入
        ↓
TodayPage 调用 Controller
        ↓
TodayController 管理异步状态
        ↓
TodayRepository 定义业务接口
        ↓
TodayRepositoryImpl 执行业务逻辑、校验、时间处理
        ↓
TodayLocalDataSource 读写 Drift
        ↓
SQLite 表 today_records / health_records
```

------

# 0. Today 模块的目录结构

现在 Today 的代码大致是：

```text
lib/features/today/
  domain/
    today_entry.dart
    today_save_data.dart
    today_repository.dart

  data/
    today_local_data_source.dart
    today_repository_impl.dart
    today_repository_provider.dart

  presentation/
    today_controller.dart
    today_page.dart
    widgets/
      today_form.dart
      duration_input_field.dart
```

这就是我们之前定的 **Feature First + Clean Architecture Lite**。

意思是：不是把所有页面都丢到 `pages/`，所有模型都丢到 `models/`，而是按功能模块组织：

```text
features/today/
features/journal/
features/growth/
```

然后每个功能里面再分：

```text
domain       业务定义
data         数据实现
presentation 页面与交互
```

------

# 1. 最上层：TodayPage

文件：

```text
lib/features/today/presentation/today_page.dart
```

`TodayPage` 是 Today 模块的页面入口。

核心代码是：

```dart
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayControllerProvider);

    return SafeArea(
      child: today.when(
        loading: () => const Center(...),
        error: (error, stackTrace) => Center(...),
        data: (entry) => TodayForm(
          entry: entry,
          onSave: (data) => _save(context, ref, data),
        ),
      ),
    );
  }
}
```

代码里可以看到，`TodayPage` 是 `ConsumerWidget`，它通过 `ref.watch(todayControllerProvider)` 监听 Today 的状态，然后根据 `loading / error / data` 三种情况显示不同界面。

## 1.1 ConsumerWidget 是什么？

普通 Flutter 页面一般是：

```dart
class MyPage extends StatelessWidget
```

但是这里是：

```dart
class TodayPage extends ConsumerWidget
```

这是 Riverpod 提供的 Widget。它比普通 `StatelessWidget` 多了一个能力：

```dart
Widget build(BuildContext context, WidgetRef ref)
```

多出来的 `ref` 可以用来读 Provider。

比如：

```dart
final today = ref.watch(todayControllerProvider);
```

这句意思是：

```text
监听 todayControllerProvider。
只要 Today 状态变化，TodayPage 自动 rebuild。
```

------

## 1.2 ref.watch 和 ref.read

在 `TodayPage` 里有两个用法。

第一个：

```dart
final today = ref.watch(todayControllerProvider);
```

`watch` 是监听：

```text
状态变了，页面跟着重建。
```

第二个：

```dart
ref.read(todayControllerProvider.notifier).saveToday(data);
```

`read` 是读取一次，不监听：

```text
适合按钮点击、保存、刷新这种一次性动作。
```

保存逻辑在 `_save()` 中：

```dart
await ref.read(todayControllerProvider.notifier).saveToday(data);
```

保存成功后用 `ScaffoldMessenger` 弹出 SnackBar：`今日记录已保存`。

所以 `TodayPage` 的职责很清楚：

```text
不处理表单细节
不处理数据库
只负责根据 Controller 状态切换 UI
只负责把保存请求转交给 Controller
```

------

# 2. 状态层：TodayController

文件：

```text
lib/features/today/presentation/today_controller.dart
```

核心代码：

```dart
final todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayEntry>(TodayController.new);

class TodayController extends AsyncNotifier<TodayEntry> {
  @override
  Future<TodayEntry> build() {
    return ref.watch(todayRepositoryProvider).getToday();
  }

  Future<void> saveToday(TodaySaveData data) {
    return _mutate(() => ref.read(todayRepositoryProvider).saveToday(data));
  }
}
```

## 2.1 AsyncNotifierProvider 是什么？

这句：

```dart
final todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayEntry>(TodayController.new);
```

可以拆成三层理解：

```text
todayControllerProvider：给 UI 使用的状态入口
TodayController：真正管理状态的类
TodayEntry：这个 Controller 管理的数据类型
```

`AsyncNotifier<TodayEntry>` 表示：

```text
这个状态是异步加载出来的，并且最终数据类型是 TodayEntry。
```

所以 UI 看到的不是普通 `TodayEntry`，而是：

```dart
AsyncValue<TodayEntry>
```

它有三种状态：

```text
AsyncLoading
AsyncError
AsyncData<TodayEntry>
```

这就是为什么 `TodayPage` 里可以写：

```dart
today.when(
  loading: ...
  error: ...
  data: ...
)
```

------

## 2.2 build() 是自动入口

`TodayController` 的 `build()`：

```dart
Future<TodayEntry> build() {
  return ref.watch(todayRepositoryProvider).getToday();
}
```

意思是：

```text
当 TodayController 第一次被使用时，自动调用 getToday()。
```

所以你打开 Today 页面，流程是：

```text
TodayPage watch todayControllerProvider
        ↓
TodayController build()
        ↓
todayRepositoryProvider.getToday()
        ↓
加载今天的 TodayEntry
```

------

## 2.3 reload 和 saveToday 的区别

`reload()`：

```dart
Future<void> reload() {
  return _reload(() => ref.read(todayRepositoryProvider).getToday());
}
```

`_reload()`：

```dart
state = const AsyncLoading<TodayEntry>();
state = await AsyncValue.guard(operation);
```

这表示重新加载时，页面会进入全局 loading。

但保存用的是 `_mutate()`：

```dart
Future<void> _mutate(Future<TodayEntry> Function() operation) async {
  final updated = await operation();
  state = AsyncData(updated);
}
```

也就是说：

```text
保存时不把整个页面切成 loading。
保存成功后，只把 state 更新为新的 TodayEntry。
```

这是 Sprint 2D 的关键优化。

------

## 2.4 _runWithCurrent 是什么？

代码里还有：

```dart
Future<void> _runWithCurrent(
  Future<TodayEntry> Function(TodayRepository repository, TodayEntry current)
  operation,
) async {
  final current = state.asData?.value;
  if (current == null) {
    return;
  }

  await _mutate(() => operation(ref.read(todayRepositoryProvider), current));
}
```

它的作用是：

```text
某些局部更新需要知道当前 recordDate。
如果当前 state 里没有 TodayEntry，就不执行。
如果有，就取出 current，然后调用 Repository。
```

比如：

```dart
updateMoodEnergy(...)
```

内部实际会调用：

```dart
repository.updateMoodEnergy(
  recordDate: current.recordDate,
  moodScore: moodScore,
  energyScore: energyScore,
);
```

这说明 Controller 不是直接操作数据库，而是：

```text
从当前状态拿 recordDate
调用 Repository
拿回新的 TodayEntry
更新 state
```

------

# 3. 表单层：TodayForm

文件：

```text
lib/features/today/presentation/widgets/today_form.dart
```

`TodayForm` 是真正收集用户输入的地方。

它是：

```dart
class TodayForm extends StatefulWidget
```

而不是 `StatelessWidget`。原因是它内部有很多临时状态，比如输入框内容、Mood 选择、保存中状态等。

------

## 3.1 StatefulWidget 的结构

Flutter 里的 `StatefulWidget` 通常分两部分：

```dart
class TodayForm extends StatefulWidget {
  ...
  @override
  State<TodayForm> createState() => _TodayFormState();
}

class _TodayFormState extends State<TodayForm> {
  ...
}
```

第一部分 `TodayForm` 负责接收外部参数：

```dart
final TodayEntry entry;
final Future<void> Function(TodaySaveData data) onSave;
```

第二部分 `_TodayFormState` 负责内部状态。

这个 `_` 开头很重要：

```dart
class _TodayFormState
```

在 Dart 中，以下划线开头的类、变量、方法都是 **library-private**，也就是“只在当前文件内可见”。

------

## 3.2 TodayForm 接收什么？

构造函数：

```dart
const TodayForm({required this.entry, required this.onSave, super.key});
```

它接收两个关键参数：

```text
entry：当前要显示的 TodayEntry
onSave：保存回调
```

这就是父子组件通信。

`TodayPage` 传入：

```dart
TodayForm(
  entry: entry,
  onSave: (data) => _save(context, ref, data),
)
```

所以 `TodayForm` 不知道 Controller 的存在，也不知道数据库。它只知道：

```text
我拿到一个 entry。
用户点击保存时，我把 TodaySaveData 交给 onSave。
```

这是很好的组件设计。

------

## 3.3 表单内部状态

`_TodayFormState` 里有这些字段：

```dart
final _formKey = GlobalKey<FormState>();
late final List<TextEditingController> _priorityControllers;
late final TextEditingController _dailyNoteController;

late List<bool> _priorityCompleted;
int? _moodScore;
int? _energyScore;
int? _physicalStateScore;
int? _researchMinutes;
int? _learningMinutes;
int? _sleepDurationMinutes;
int? _exerciseDurationMinutes;
bool _isSaving = false;
```

逐个解释：

```text
_formKey：控制整个 Form，用于统一 validate。
_priorityControllers：三个“今日三件事”的输入框控制器。
_dailyNoteController：一句话记录的输入框控制器。
_priorityCompleted：三个事项是否完成。
_moodScore / _energyScore：Mood 和 Energy 分数。
_researchMinutes / _learningMinutes：科研/学习时间，底层仍是分钟。
_sleepDurationMinutes / _exerciseDurationMinutes：睡眠/运动时间。
_isSaving：保存按钮是否处于“保存中”。
```

------

## 3.4 late final 是什么？

例如：

```dart
late final TextEditingController _dailyNoteController;
```

`final` 表示：

```text
只能赋值一次。
```

`late` 表示：

```text
我保证稍后会初始化它。
```

这里是在 `initState()` 中初始化：

```dart
_dailyNoteController = TextEditingController();
```

所以：

```dart
late final
```

适合这种场景：

```text
对象创建时不能立即初始化，
但在使用前一定会初始化，
而且只初始化一次。
```

------

## 3.5 initState / didUpdateWidget / dispose

TodayForm 有三个生命周期方法：

```dart
initState()
didUpdateWidget(...)
dispose()
```

### initState

```dart
@override
void initState() {
  super.initState();
  _priorityControllers = List<TextEditingController>.generate(
    3,
    (_) => TextEditingController(),
  );
  _dailyNoteController = TextEditingController();
  _syncFromEntry(widget.entry);
}
```

意思是：

```text
组件第一次创建时：
1. 创建三个 priority 输入框控制器
2. 创建 daily note 输入框控制器
3. 把 entry 的数据同步到表单
```

### didUpdateWidget

```dart
if (!identical(oldWidget.entry, widget.entry)) {
  _syncFromEntry(widget.entry);
}
```

意思是：

```text
如果父组件传进来的 entry 变了，就把新 entry 同步到表单。
```

比如保存成功后 Controller 返回一个新的 TodayEntry，TodayPage rebuild，TodayForm 会收到新的 `entry`。

### dispose

```dart
for (final controller in _priorityControllers) {
  controller.dispose();
}
_dailyNoteController.dispose();
```

输入框控制器会占用资源，所以 Widget 销毁时要释放。

这是 Flutter 写表单时非常重要的习惯。

------

# 4. TodayForm 的 UI 结构

`build()` 里返回：

```dart
return Form(
  key: _formKey,
  child: ListView(
    ...
  ),
);
```

几个关键 Widget：

```text
Form：表单容器，用于统一校验。
ListView：可滚动列表，避免内容超出屏幕。
ConstrainedBox：限制最大宽度，Windows 桌面上不会太宽。
Column：纵向排列。
LayoutBuilder：根据宽度调整布局。
Wrap：空间不足时自动换行。
TextFormField：带校验能力的输入框。
SegmentedButton：Mood/Energy 的 1–5 选择。
FilledButton.icon：保存按钮。
```

------

## 4.1 `if (...) ...[]` 是 Dart 的 collection if + spread

代码里有：

```dart
if (!_hasAnyInput) ...[
  const SizedBox(height: 6),
  Text('今天还没有填写内容', ...)
],
```

这是 Dart 在 list 里面的写法。

意思是：

```text
如果 _hasAnyInput 为 false，就把这两个 Widget 插入 children 列表。
```

其中 `...[]` 叫 spread operator，表示“展开列表”。

------

## 4.2 今日三件事

TodayForm 用循环生成三个 priority 输入框：

```dart
for (var index = 0; index < 3; index++) ...[
  _buildPriorityField(index),
  if (index < 2) const SizedBox(height: 10),
],
```

这体现了产品规则：

```text
Today 固定三件事。
```

每个 priority 由 `_buildPriorityField(index)` 创建。

里面有 Checkbox 和 TextFormField：

```dart
Checkbox(
  value: hasText && _priorityCompleted[index],
  onChanged: hasText ? (...) : null,
)
```

这里的设计是：

```text
如果没有文字，checkbox 禁用。
如果文字被清空，completed 自动变 false。
```

清空逻辑：

```dart
if (value.trim().isEmpty) {
  _priorityCompleted[index] = false;
}
```

这就避免了“空任务被标记完成”的脏数据。

------

## 4.3 Mood / Energy / 身体状态

Mood 和 Energy 使用 `_ScoreField`，内部是 `SegmentedButton<int>`：

```dart
segments: const <ButtonSegment<int>>[
  ButtonSegment(value: 1, label: Text('1')),
  ...
  ButtonSegment(value: 5, label: Text('5')),
],
selected: value == null ? const <int>{} : <int>{value!},
emptySelectionAllowed: true,
```

几个语法点：

### 泛型 `<int>`

```dart
SegmentedButton<int>
```

表示这个按钮组选择的值是 `int`。

### Set

```dart
<int>{value!}
```

这是一个 `Set<int>`，因为 `SegmentedButton` 的 `selected` 参数要求集合。

### `value!`

`value` 是 `int?`，可能为 null。

但在这里：

```dart
value == null ? const <int>{} : <int>{value!}
```

既然走到右边分支，说明 `value` 不为 null，所以用 `value!` 告诉 Dart：

```text
我确定这里不是 null。
```

### `emptySelectionAllowed: true`

表示允许不选择任何分数。

所以 Mood / Energy / 身体状态都可以是：

```text
null：没填
1–5：用户选择的分数
```

------

# 5. DurationInputField：时间输入组件

文件：

```text
lib/features/today/presentation/widgets/duration_input_field.dart
```

这是 Sprint 2E 做的组件。

它的接口：

```dart
class DurationInputField extends StatefulWidget {
  const DurationInputField({
    required this.label,
    required this.initialMinutes,
    required this.onChanged,
    this.quickValues = const <int>[],
    super.key,
  });

  final String label;
  final int? initialMinutes;
  final ValueChanged<int?> onChanged;
  final List<int> quickValues;
}
```

它做一件事：

```text
UI 显示“小时 + 分钟”
内部输出 int? totalMinutes
```

------

## 5.1 ValueChanged<int?> 是什么？

```dart
final ValueChanged<int?> onChanged;
```

`ValueChanged<T>` 本质是：

```dart
void Function(T value)
```

所以：

```dart
ValueChanged<int?>
```

等价于：

```dart
void Function(int? value)
```

意思是：

```text
当输入变化时，把 int? 分钟数传给父组件。
```

------

## 5.2 初始值如何拆分

初始化时：

```dart
_setTotalMinutes(widget.initialMinutes, notify: false);
```

核心逻辑：

```dart
if (totalMinutes == null) {
  _hoursController.text = '';
  _minutesController.text = '';
} else {
  _hoursController.text = (totalMinutes ~/ 60).toString();
  _minutesController.text = (totalMinutes % 60).toString();
}
```

这里有两个 Dart 运算符：

```dart
~/   整除
%    取余
```

例如：

```dart
90 ~/ 60 = 1
90 % 60 = 30
```

所以：

```text
90 分钟 -> 1 小时 30 分钟
420 分钟 -> 7 小时 0 分钟
null -> 空 / 空
```

------

## 5.3 输入校验

小时校验：

```dart
final hours = int.tryParse(text);
if (hours == null || hours < 0) {
  return '请输入非负整数';
}
```

分钟校验：

```dart
final minutes = int.tryParse(text);
if (minutes == null || minutes < 0) {
  return '请输入 0–59 的整数';
}
if (minutes >= 60) {
  return '分钟需小于 60';
}
```

这里 `int.tryParse(text)` 很关键：

```text
能转成整数 -> 返回 int
不能转成整数 -> 返回 null
```

所以：

```text
"30" -> 30
"abc" -> null
"1.5" -> null
"-1" -> -1
```

------

## 5.4 合法输入如何输出

```dart
if (hoursText.isEmpty && minutesText.isEmpty) {
  widget.onChanged(null);
  return;
}

final hours = hoursText.isEmpty ? 0 : int.parse(hoursText);
final minutes = minutesText.isEmpty ? 0 : int.parse(minutesText);
widget.onChanged(hours * 60 + minutes);
```

转换规则：

```text
空 + 空 -> null
1 + 空 -> 60
空 + 30 -> 30
1 + 30 -> 90
0 + 0 -> 0
```

这很好地保留了 Rebirth 的核心数据语义：

```text
null = 用户没填
0 = 用户明确填了 0
```

------

## 5.5 快捷 chips

代码：

```dart
for (final totalMinutes in widget.quickValues)
  ActionChip(
    label: Text(_formatQuickValue(totalMinutes)),
    onPressed: () => _applyQuickValue(totalMinutes),
  ),
```

`quickValues` 本质仍是分钟：

```dart
[15, 30, 45, 60, 90, 120]
```

TodayForm 中定义：

```dart
static const _standardDurationQuickValues = <int>[15, 30, 45, 60, 90, 120];
static const _sleepDurationQuickValues = <int>[360, 390, 420, 450, 480, 510];
```

显示时格式化为：

```dart
if (hours == 0) return '$minutes分钟';
if (minutes == 0) return '$hours小时';
return '$hours小时$minutes分钟';
```

所以 UI 上看到的是：

```text
15分钟
1小时
1小时30分钟
7小时30分钟
```

但底层仍是：

```text
15
60
90
450
```

------

# 6. TodayForm 保存时发生什么

保存按钮：

```dart
FilledButton.icon(
  key: const ValueKey('saveTodayButton'),
  onPressed: _isSaving ? null : _submit,
  icon: _isSaving ? CircularProgressIndicator(...) : Icon(...),
  label: Text(_isSaving ? '保存中...' : '保存'),
)
```

这表示：

```text
保存中：按钮禁用，显示保存中...
非保存中：可以点击，显示保存
```

点击后进入 `_submit()`。

------

## 6.1 表单校验

```dart
if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
  return;
}
```

拆开看：

```text
_isSaving：正在保存时不允许重复保存。
_formKey.currentState?.validate()：运行整个 Form 的所有 validator。
?? false：如果 currentState 是 null，则当作 false。
```

这是 Dart 的空安全写法。

------

## 6.2 生成 TodayPriority 列表

```dart
final priorities = List<TodayPriority>.generate(3, (index) {
  return TodayPriority(
    text: _nullableText(_priorityControllers[index].text),
    completed: _priorityCompleted[index],
    goalId: widget.entry.priorities[index].goalId,
  );
}, growable: false);
```

这里有几个点：

```dart
List<TodayPriority>.generate(3, ...)
```

生成长度为 3 的列表。

```dart
growable: false
```

表示这个 List 不能再增加或删除元素。

`_nullableText()`：

```dart
String? _nullableText(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}
```

这就实现了：

```text
空字符串 -> null
"  完成实验  " -> "完成实验"
```

------

## 6.3 生成 TodaySaveData

```dart
final data = TodaySaveData(
  priorities: priorities,
  moodScore: _moodScore,
  energyScore: _energyScore,
  researchMinutes: _researchMinutes,
  learningMinutes: _learningMinutes,
  dailyNote: _nullableText(_dailyNoteController.text),
  status: widget.entry.status,
  health: _buildHealthInput(),
);
```

这一步非常重要：

```text
TodayForm 不直接保存数据库。
它只是把 UI 当前状态包装成 TodaySaveData。
```

然后：

```dart
await widget.onSave(data);
```

这个 `onSave` 是从 `TodayPage` 传进来的，最终会调用 Controller。

------

## 6.4 Health 隐藏字段保留

`_buildHealthInput()`：

```dart
final existing = widget.entry.health;

return TodayHealthInput(
  sleepDurationMinutes: _sleepDurationMinutes,
  weightKg: existing?.weightKg,
  waterIntakeMl: existing?.waterIntakeMl,
  exerciseType: existing?.exerciseType,
  exerciseDurationMinutes: _exerciseDurationMinutes,
  physicalStateScore: _physicalStateScore,
  note: existing?.note,
);
```

这段设计很细。

现在 Today UI 只展示：

```text
睡眠时长
运动时长
身体状态
```

但 Health 表里还有：

```text
weightKg
waterIntakeMl
exerciseType
note
```

这些字段当前 UI 不展示。

如果保存时不保留它们，就会把未来 Health 模块写入的数据覆盖掉。现在的逻辑用：

```dart
existing?.weightKg
```

保留已有隐藏字段。

这就是“局部编辑不能破坏未展示字段”。

------

# 7. Domain 层：TodayEntry / TodaySaveData

现在往下看业务模型。

文件：

```text
lib/features/today/domain/today_entry.dart
```

------

## 7.1 TodayEntry 是什么

`TodayEntry` 是 UI 和 Controller 看到的“今天记录”。

它包含：

```dart
final String id;
final String userId;
final String recordDate;
final int timezoneOffsetMinutes;
final List<TodayPriority> priorities;
final int? moodScore;
final int? energyScore;
final int? researchMinutes;
final int? learningMinutes;
final String? dailyNote;
final TodayRecordStatus status;
final int createdAt;
final int updatedAt;
final TodayHealthSummary? health;
```

注意它不是数据库表对象，而是领域对象。

数据库中 Today 和 Health 是两张表：

```text
today_records
health_records
```

但领域层把它们聚合成：

```dart
TodayEntry {
  ...
  TodayHealthSummary? health;
}
```

这就是聚合模型。

------

## 7.2 为什么 TodayEntry 要强制 3 个 priorities？

构造函数中有：

```dart
if (priorities.length != 3) {
  throw ArgumentError.value(
    priorities.length,
    'priorities',
    'Today entries must contain exactly three priority slots.',
  );
}
```

这说明：

```text
“今日三件事”不是 UI 临时规则，而是业务规则。
```

即使未来换 UI，这个规则仍然被 Domain 层保护。

------

## 7.3 TodayPriority

```dart
final class TodayPriority {
  const TodayPriority({this.text, this.completed = false, this.goalId});

  final String? text;
  final bool completed;
  final String? goalId;

  bool get isPopulated => text != null && text!.trim().isNotEmpty;
}
```

这里有两个语法点：

### `this.text`

构造函数里的：

```dart
const TodayPriority({this.text, this.completed = false, this.goalId});
```

等价于：

```dart
TodayPriority({String? text, bool completed = false, String? goalId})
  : this.text = text,
    this.completed = completed,
    this.goalId = goalId;
```

Dart 提供了简写。

### getter

```dart
bool get isPopulated => ...
```

这是 getter，不是普通方法。

调用时写：

```dart
priority.isPopulated
```

而不是：

```dart
priority.isPopulated()
```

------

## 7.4 TodaySaveData 是什么

文件：

```text
today_save_data.dart
```

`TodaySaveData` 是保存请求的数据包：

```dart
final class TodaySaveData {
  TodaySaveData({
    List<TodayPriority> priorities = const <TodayPriority>[
      TodayPriority(),
      TodayPriority(),
      TodayPriority(),
    ],
    this.moodScore,
    this.energyScore,
    this.researchMinutes,
    this.learningMinutes,
    this.dailyNote,
    this.status = TodayRecordStatus.draft,
    this.health,
  }) : priorities = List<TodayPriority>.unmodifiable(priorities);
}
```

你要区分：

```text
TodayEntry：已经从数据库读出的完整记录
TodaySaveData：准备提交保存的数据
```

这两个不要混用。

------

# 8. Repository 接口：TodayRepository

文件：

```text
today_repository.dart
```

核心：

```dart
abstract interface class TodayRepository {
  Future<TodayEntry> getToday();

  Future<TodayEntry?> getByDate(String recordDate);

  Future<TodayEntry> saveToday(TodaySaveData data);

  Future<TodayEntry> updatePriorities(...);

  Future<TodayEntry> updateMoodEnergy(...);

  Future<TodayEntry> updateResearchLearningMinutes(...);

  Future<TodayEntry> updateDailyNote(...);

  Future<TodayEntry> markCompleted(...);
}
```

## 8.1 abstract interface class

这是 Dart 3 的接口写法。

意思是：

```text
TodayRepository 只定义能力，不提供实现。
```

谁实现？

```text
TodayRepositoryImpl
```

为什么要这样做？

因为 UI 和 Controller 不应该依赖具体数据库实现。

Controller 只知道：

```dart
TodayRepository repository
```

不知道：

```dart
TodayRepositoryImpl
Drift
SQLite
AppDatabase
```

这叫依赖倒置。

------

# 9. Provider：todayRepositoryProvider

文件：

```text
today_repository_provider.dart
```

代码：

```dart
final todayRepositoryProvider = Provider<TodayRepository>((ref) {
  return TodayRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
  );
});
```

这就是依赖注入。

意思是：

```text
当有人需要 TodayRepository 时，
Riverpod 会创建 TodayRepositoryImpl，
并自动把 AppDatabase 和 DateTimeService 注入进去。
```

所以 Controller 里只需要：

```dart
ref.read(todayRepositoryProvider)
```

不需要自己写：

```dart
TodayRepositoryImpl(
  database: ...,
  dateTimeService: ...,
)
```

------

# 10. RepositoryImpl：业务逻辑层

文件：

```text
today_repository_impl.dart
```

`TodayRepositoryImpl` 是真正执行业务规则的地方。

构造函数：

```dart
TodayRepositoryImpl({
  required AppDatabase database,
  required this.dateTimeService,
}) : _database = database,
     _localDataSource = TodayLocalDataSource(database);
```

它持有：

```text
_database：Drift 数据库入口
dateTimeService：统一时间服务
_localDataSource：实际数据库读写对象
```

------

## 10.1 getToday()

```dart
Future<TodayEntry> getToday() async {
  final snapshot = dateTimeService.currentSnapshot();
  final bootstrap = await _database.bootstrapDao.bootstrap();
  final entry = await _localDataSource.getOrCreate(
    userId: bootstrap.activeUserId,
    recordDate: snapshot.localDateString,
    timezoneOffsetMinutes: snapshot.timezoneOffsetMinutes,
    timestamp: snapshot.utcMilliseconds,
    originDeviceId: bootstrap.localInstallationId,
  );

  return _toDomain(entry);
}
```

这段非常关键。

### currentSnapshot()

它一次性拿到：

```text
今天的本地日期字符串
当前 UTC 时间戳
当前时区 offset
```

为什么不用三次 `DateTime.now()`？

因为可能出现跨午夜问题。

比如：

```text
第一次 DateTime.now()：23:59:59
第二次 DateTime.now()：00:00:00
```

那日期和时间戳可能不一致。

所以我们用 `currentSnapshot()` 一次拿齐。

### bootstrap()

```dart
final bootstrap = await _database.bootstrapDao.bootstrap();
```

它保证当前数据库里有 active user 和 app settings。

所以每次业务操作都知道：

```text
当前用户是谁
当前设备 localInstallationId 是什么
```

### getOrCreate()

Today 的特殊点是：

```text
打开今天页面时，如果今天没有记录，就自动创建一条空记录。
```

所以 `getToday()` 调的是：

```dart
_localDataSource.getOrCreate(...)
```

而不是单纯查询。

------

## 10.2 getByDate()

```dart
Future<TodayEntry?> getByDate(String recordDate) async {
  _validateRecordDate(recordDate);
  final bootstrap = await _database.bootstrapDao.bootstrap();
  final entry = await _localDataSource.getByDate(
    userId: bootstrap.activeUserId,
    recordDate: recordDate,
  );

  return entry == null ? null : _toDomain(entry);
}
```

这是未来 Today History 会用的接口。

它不会自动创建。

所以：

```text
getToday()：今天没有就创建
getByDate(date)：指定日期没有就返回 null
```

这个语义区分很重要。

------

## 10.3 saveToday()

`saveToday()` 先做校验：

```dart
final priorities = _normalizePriorities(data.priorities);
_validateScore(data.moodScore, 'moodScore');
_validateScore(data.energyScore, 'energyScore');
_validateMinutes(data.researchMinutes, 'researchMinutes');
_validateMinutes(data.learningMinutes, 'learningMinutes');
_validateHealth(data.health);
```

然后获取时间和用户：

```dart
final snapshot = dateTimeService.currentSnapshot();
final bootstrap = await _database.bootstrapDao.bootstrap();
```

再调用 DataSource：

```dart
final entry = await _localDataSource.saveAggregate(...)
```

## 10.4 TodayRecordsCompanion 和 Value

保存时有：

```dart
TodayRecordsCompanion(
  moodScore: Value(data.moodScore),
  energyScore: Value(data.energyScore),
  researchMinutes: Value(data.researchMinutes),
  learningMinutes: Value(data.learningMinutes),
  dailyNote: Value(data.dailyNote),
  updatedAt: Value(snapshot.utcMilliseconds),
)
```

这是 Drift 的写法。

`Companion` 表示：

```text
我要插入或更新哪些字段。
```

`Value(...)` 表示：

```text
这个字段我要写入。
```

哪怕值是 null，也会写入 null。

这对 Rebirth 特别重要，因为：

```text
字段没传 ≠ 字段传 null
```

例如：

```dart
dailyNote: Value(null)
```

意思是：

```text
把 daily_note 清空为 NULL。
```

而不是“不更新 daily_note”。

------

## 10.5 数据库对象转领域对象：_toDomain()

RepositoryImpl 的 `_toDomain()` 把 Drift 生成的数据对象转换成业务对象：

```dart
return TodayEntry(
  id: today.id,
  userId: today.userId,
  recordDate: today.recordDate,
  ...
  health: health == null
      ? null
      : TodayHealthSummary(...),
);
```

这是架构里很重要的一层隔离。

数据库对象是：

```text
TodayRecord
HealthRecord
```

领域对象是：

```text
TodayEntry
TodayHealthSummary
```

UI 永远不应该直接使用 Drift 的 `TodayRecord`。

------

## 10.6 normalize 和 validate

`_normalizePriorities()`：

```dart
if (priorities.length > 3) {
  throw ArgumentError.value(...);
}

return List<TodayPriority>.generate(3, (index) {
  if (index >= priorities.length) {
    return const TodayPriority();
  }

  final priority = priorities[index];
  final text = priority.text?.trim();
  return TodayPriority(
    text: text == null || text.isEmpty ? null : text,
    completed: priority.completed,
    goalId: priority.goalId,
  );
}, growable: false);
```

这保证：

```text
最多 3 个 priority
不足 3 个自动补空
文字会 trim
空字符串转 null
```

分数校验：

```dart
if (score != null && (score < 1 || score > 5)) {
  throw ArgumentError.value(score, name, 'Score must be between 1 and 5.');
}
```

分钟校验：

```dart
if (minutes != null && minutes < 0) {
  throw ArgumentError.value(minutes, name, 'Minutes must not be negative.');
}
```

这里体现了一个原则：

```text
UI 可以校验，但 Repository 仍然必须校验。
```

因为以后不一定只有 UI 会调用 Repository。

------

# 11. LocalDataSource：数据库读写层

文件：

```text
today_local_data_source.dart
```

它比 Repository 更底层。

Repository 关心：

```text
业务规则
用户
时间
校验
领域模型转换
```

LocalDataSource 关心：

```text
怎么 select
怎么 insert
怎么 update
怎么 transaction
```

------

## 11.1 TodayDatabaseEntry

```dart
final class TodayDatabaseEntry {
  const TodayDatabaseEntry({required this.today, required this.health});

  final TodayRecord today;
  final HealthRecord? health;
}
```

这是 Data 层内部对象。

它把数据库的两张表组合起来：

```text
TodayRecord + HealthRecord?
```

注意它不是 Domain 层对象，所以不会暴露给 UI。

------

## 11.2 getByDate()

```dart
final today = await _findToday(userId: userId, recordDate: recordDate);
if (today == null) {
  return null;
}

return TodayDatabaseEntry(
  today: today,
  health: await _findHealth(userId: userId, recordDate: recordDate),
);
```

这说明：

```text
读取某天记录时，会同时读取同日 HealthRecord。
```

------

## 11.3 getOrCreate()

```dart
return database.transaction(() async {
  await _ensureToday(...);
  return (await getByDate(userId: userId, recordDate: recordDate))!;
});
```

`transaction` 是事务。

意思是：

```text
里面所有数据库操作要么全部成功，要么全部回滚。
```

`!` 的意思是 non-null assertion：

```dart
(...)!
```

因为 `_ensureToday()` 已经保证 TodayRecord 存在，所以这里告诉 Dart：

```text
我确定 getByDate 不会返回 null。
```

------

## 11.4 saveAggregate()

```dart
return database.transaction(() async {
  final today = await _ensureToday(...);

  await database.update(database.todayRecords)
    ...
    .write(todayChanges);

  if (health != null) {
    await _upsertHealth(...);
  }

  return (await getByDate(userId: userId, recordDate: recordDate))!;
});
```

这是 Today 保存的核心数据库逻辑。

为什么叫 aggregate？

因为它保存的不是单表，而是一个聚合：

```text
today_records
+
health_records
```

也就是说：

```text
Today 页面的一次保存，可能同时影响 TodayRecord 和 HealthRecord。
```

用 transaction 可以保证它们一致。

------

## 11.5 _ensureToday()

```dart
final existing = await _findToday(userId: userId, recordDate: recordDate);
if (existing != null) {
  return existing;
}

final id = _uuid.v4();
await database.into(database.todayRecords).insert(...);
return (await _findToday(userId: userId, recordDate: recordDate))!;
```

这就是“没有就创建，有就返回”。

`_uuid.v4()` 用来生成本地唯一 ID。

------

## 11.6 _upsertHealth()

`upsert` 是：

```text
update + insert
```

也就是：

```text
有就更新
没有就插入
```

代码逻辑：

```dart
final existing = await _findHealth(...);

if (existing == null) {
  await database.into(database.healthRecords).insert(...);
  return;
}

await database.update(database.healthRecords)...write(...);
```

这就是 HealthRecord 的 upsert。

------

## 11.7 Drift 查询语法

`_findToday()`：

```dart
return (database.select(database.todayRecords)..where(
      (row) =>
          row.userId.equals(userId) &
          row.recordDate.equals(recordDate) &
          row.deletedAt.isNull(),
    ))
    .getSingleOrNull();
```

解释：

```text
database.select(database.todayRecords)
  查询 today_records 表

..where(...)
  cascade operator，继续给查询对象添加 where 条件

row.userId.equals(userId)
  user_id = ?

&
  Drift 中的 AND 条件

row.deletedAt.isNull()
  deleted_at IS NULL

getSingleOrNull()
  返回一条记录；如果没有，返回 null
```

这里 `..` 是 Dart 的 cascade operator。

普通写法可能是：

```dart
final query = database.select(database.todayRecords);
query.where(...);
return query.getSingleOrNull();
```

`..` 可以简化成链式写法。

------

# 12. 数据库层：Drift Table

Today 使用两张表：

```text
today_records
health_records
```

------

## 12.1 TodayRecords 表

文件：

```text
today_records_table.dart
```

Drift 表定义：

```dart
@DataClassName('TodayRecord')
class TodayRecords extends Table
    with UuidPrimaryKey, SyncableColumns, SoftDeleteColumn {
```

这表示：

```text
SQLite 表：today_records
Dart 数据类：TodayRecord
混入公共列：UUID 主键、同步字段、软删除字段
```

主要字段：

```dart
TextColumn get userId => ...
TextColumn get recordDate => text()();
IntColumn get timezoneOffsetMinutes => integer()();

TextColumn get priority1 => text().named('priority_1').nullable()();
BoolColumn get priority1Completed => boolean().named('priority_1_completed')...

IntColumn get moodScore => integer().nullable()();
IntColumn get energyScore => integer().nullable()();
IntColumn get researchMinutes => integer().nullable()();
IntColumn get learningMinutes => integer().nullable()();
TextColumn get dailyNote => text().nullable()();
TextColumn get recordStatus => text().withDefault(const Constant('draft'))();
```

这里能看到数据库命名是 snake_case：

```text
priority_1
priority_1_completed
record_status
```

Dart 命名是 camelCase：

```text
priority1
priority1Completed
recordStatus
```

------

## 12.2 数据库约束

TodayRecords 里有 CHECK 约束：

```dart
'CHECK (mood_score IS NULL OR mood_score BETWEEN 1 AND 5)',
'CHECK (energy_score IS NULL OR energy_score BETWEEN 1 AND 5)',
'CHECK (research_minutes IS NULL OR research_minutes >= 0)',
'CHECK (learning_minutes IS NULL OR learning_minutes >= 0)',
"CHECK (record_status IN ('draft', 'completed'))",
```

这说明即使 Repository 漏校验，数据库也会保护基本合法性。

架构上是三层保护：

```text
UI 校验
Repository 校验
Database CHECK 约束
```

------

## 12.3 HealthRecords 表

Health 表包含：

```dart
sleepDurationMinutes
weightKg
waterIntakeMl
exerciseType
exerciseDurationMinutes
physicalStateScore
note
dataSource
sourceRecordId
```

约束包括：

```dart
'CHECK (sleep_duration_minutes IS NULL OR sleep_duration_minutes >= 0)',
'CHECK (weight_kg IS NULL OR weight_kg > 0)',
'CHECK (physical_state_score IS NULL OR physical_state_score BETWEEN 1 AND 5)',
```

Today 页面目前只用了其中一部分：

```text
sleepDurationMinutes
exerciseDurationMinutes
physicalStateScore
```

但保留了其他字段，方便未来 Health 模块扩展。

------

# 13. 一次完整保存的调用链

现在你可以把一次保存看成：

```text
用户点击保存
  ↓
TodayForm._submit()
  ↓
生成 TodaySaveData
  ↓
widget.onSave(data)
  ↓
TodayPage._save()
  ↓
todayControllerProvider.notifier.saveToday(data)
  ↓
TodayController.saveToday()
  ↓
TodayRepositoryImpl.saveToday()
  ↓
校验 + normalize
  ↓
DateTimeService.currentSnapshot()
  ↓
Bootstrap active user
  ↓
TodayLocalDataSource.saveAggregate()
  ↓
database.transaction()
  ↓
_ensureToday()
  ↓
update today_records
  ↓
_upsertHealth()
  ↓
getByDate()
  ↓
TodayRepositoryImpl._toDomain()
  ↓
TodayController state = AsyncData(updated)
  ↓
TodayPage / TodayForm rebuild
  ↓
SnackBar: 今日记录已保存
```

这就是完整闭环。

你以后读 Journal 模块，也可以按这个顺序看：

```text
Page
Controller
Form
SaveData
Repository Interface
Repository Impl
LocalDataSource
Drift Table
```

------

# 14. 今天你需要重点掌握的 Dart / Flutter 语法

## 14.1 `class X extends Y`

```dart
class TodayPage extends ConsumerWidget
```

表示 `TodayPage` 继承 `ConsumerWidget`，拥有它的能力。

------

## 14.2 `@override`

```dart
@override
Widget build(...)
```

表示这个方法重写父类方法。

Flutter 的 Widget 基本都要重写 `build()`。

------

## 14.3 `const`

```dart
const TodayPage({super.key});
```

`const` 表示编译期常量构造，可以减少不必要 rebuild 成本。

------

## 14.4 `required this.xxx`

```dart
const TodayForm({required this.entry, required this.onSave, super.key});
```

表示构造时必须传入 `entry` 和 `onSave`。

------

## 14.5 `?`

```dart
int? _moodScore;
String? dailyNote;
```

表示可以为 null。

在 Rebirth 里，`null` 是有业务意义的：

```text
null = 用户没填
0 = 用户明确填了 0
```

------

## 14.6 `!`

```dart
value!
```

表示我确认它不是 null。

这个要谨慎使用。项目里主要在已经判断过不为 null 的地方使用。

------

## 14.7 `async / await / Future`

```dart
Future<void> saveToday(...) async {
  await ...
}
```

数据库、文件、网络操作都是异步的，所以返回 `Future`。

`await` 表示等结果回来再继续。

------

## 14.8 `=>`

```dart
bool get isPopulated => text != null && text!.trim().isNotEmpty;
```

这是单表达式函数/ getter 的简写。

------

## 14.9 三元表达式

```dart
value == null ? const <int>{} : <int>{value!}
```

格式：

```dart
condition ? whenTrue : whenFalse
```

------

## 14.10 cascade operator `..`

```dart
database.select(database.todayRecords)..where(...)
```

`..` 表示对同一个对象连续调用方法。

------

# 15. 这个模块的架构价值

Today 模块现在是 Rebirth 的样板模块。

它的价值不只是“有一个 Today 页面”，而是已经建立了以后所有模块都可以复用的模式：

```text
纯领域模型，不暴露数据库对象
Repository 接口隔离业务能力
RepositoryImpl 处理校验、时间、用户、映射
LocalDataSource 只做数据库操作
Controller 管理异步状态
Page 根据 AsyncValue 渲染
Form 只负责收集输入
```

所以 Journal 后续也应该保持这个模式：

```text
JournalEntry
JournalSaveData
JournalRepository
JournalRepositoryImpl
JournalLocalDataSource
JournalController
JournalForm
```

Today 模块你真正要记住的是这句话：

> **UI 不碰数据库，Controller 不碰 Drift，Repository 不碰 Widget，DataSource 不碰业务展示。**

这就是现在 Rebirth 代码开始变得可维护的核心原因。