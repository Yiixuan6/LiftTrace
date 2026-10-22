import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/controller.dart';
import '../domain/models.dart';
import '../platform/reminders.dart';
import 'components.dart';
import 'library.dart';
import 'workout_set_row.dart';

final remindersProvider = Provider<RestReminders>((ref) => RestReminders());
String clock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

class ActiveWorkoutPage extends ConsumerStatefulWidget {
  const ActiveWorkoutPage({super.key, this.sessionId});
  final String? sessionId;
  @override
  ConsumerState<ActiveWorkoutPage> createState() => _ActiveState();
}

class _ActiveState extends ConsumerState<ActiveWorkoutPage>
    with WidgetsBindingObserver {
  Timer? tick;
  bool finishing = false;
  bool completing = false;
  final invalidSets = <String>{};
  String? mainError;
  RestReminderStatus? reminderStatus;
  bool notificationPrompted = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshReminders());
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshReminders());
  }

  Future<void> refreshReminders() async {
    try {
      final status = await ref.read(remindersProvider).status();
      if (!mounted) return;
      final improved =
          reminderStatus != null && !reminderStatus!.ready && status.ready;
      setState(() => reminderStatus = status);
      if (improved) {
        final deadline = DateTime.tryParse(
          ref.read(controllerProvider).data.settings['restDeadline']
                  as String? ??
              '',
        );
        if (deadline != null && deadline.isAfter(DateTime.now())) {
          await ref.read(remindersProvider).schedule(deadline);
        }
      }
    } catch (_) {
      if (mounted) setState(() => reminderStatus = const RestReminderStatus());
    }
  }

  void restMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          showCloseIcon: true,
          content: Text(text),
          action: SnackBarAction(
            label: '提醒设置',
            onPressed: () => unawaited(enableReminders()),
          ),
        ),
      );
  }

  Future<void> appendSet(AppController c, String sessionId, String moveId) =>
      c.updateSession(sessionId, (s) {
        final target = s.exercises.firstWhere((e) => e.id == moveId);
        (target.data['sets'] as List).add(WorkoutSet.empty().toJson());
      });

  Future<void> chooseSetTarget(AppController c, Session session) async {
    final moves = session.exercises.where((e) => !e.skipped).toList();
    if (moves.isEmpty) return;
    final targetId = moves.length == 1
        ? moves.single.id
        : await showEditorialDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('给哪个动作新增一组？'),
              children: [
                for (final (i, move)
                    in session.exercises.indexed.toList().reversed)
                  if (!move.skipped)
                    SimpleDialogOption(
                      key: ValueKey('add-set-target-${move.id}'),
                      onPressed: () => Navigator.pop(context, move.id),
                      child: Text('${i + 1}. ${move.exercise.name}'),
                    ),
              ],
            ),
          );
    if (targetId != null && mounted) {
      await appendSet(c, session.id, targetId);
    }
  }

  Future<void> enableReminders() async {
    try {
      final reminders = ref.read(remindersProvider);
      await reminders.initialize();
      await reminders.requestPermissions(precise: true);
      final status = await reminders.status();
      if (!mounted) return;
      setState(() => reminderStatus = status);
      if (!status.notificationsAllowed ||
          !status.popupAllowed ||
          !status.vibrationAllowed) {
        await reminders.openSettings(
          applicationLevel:
              !status.notificationsAllowed || !status.vibrationAllowed,
        );
      }
      // Upgrade any already-running inexact alarm after permission is granted.
      final deadline = DateTime.tryParse(
        ref.read(controllerProvider).data.settings['restDeadline'] as String? ??
            '',
      );
      if (deadline != null && deadline.isAfter(DateTime.now())) {
        await reminders.schedule(deadline);
      }
    } catch (_) {
      restMessage('提醒组件未能启动，请重试；若仍失败请保留计时并反馈');
    }
  }

  int restSeconds(AppController c, WorkoutExercise move) =>
      (c.data.settings['restPresetSeconds'] as num?)?.toInt() ??
      (move.data['restSeconds'] as num?)?.toInt() ??
      90;

  Future<void> setRest(
    AppController c,
    int? seconds, {
    bool preset = false,
  }) async {
    final target = seconds == null
        ? null
        : DateTime.now().add(Duration(seconds: seconds));
    await c.change((d) {
      if (preset && seconds != null) {
        d.settings['restPresetSeconds'] = seconds;
      }
      d.settings.remove('restRemaining');
      d.settings['restDeadline'] = target?.toUtc().toIso8601String();
    });
    try {
      final reminders = ref.read(remindersProvider);
      if (seconds == null) {
        await reminders.cancel();
      } else {
        final before = await reminders.status();
        // A user-initiated rest is the only automatic notification prompt.
        // Do not repeatedly prompt after a refusal, or request on app launch.
        if (before.supported &&
            !before.notificationsAllowed &&
            !notificationPrompted) {
          notificationPrompted = true;
          await reminders.requestPermissions();
        }
        final status = await reminders.schedule(target!);
        if (mounted) setState(() => reminderStatus = status);
        if (status.supported && !status.ready) restMessage(status.message);
      }
    } catch (_) {
      restMessage(seconds == null ? '系统提醒未能取消，请检查通知设置' : '本组和计时已保存，系统提醒暂不可用');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final session = widget.sessionId == null
        ? c.data.active
        : c.data.sessions
              .where((s) => s.id == widget.sessionId && !s.deleted)
              .firstOrNull;
    if (session == null) {
      return PageBody(
        preserveLayout: true,
        title: '训练',
        children: [
          EmptyState(
            message: '当前没有训练',
            action: FilledButton(
              onPressed: () => context.go('/train'),
              child: const Text('返回训练'),
            ),
          ),
        ],
      );
    }
    final deadline = DateTime.tryParse(
      c.data.settings['restDeadline'] as String? ?? '',
    );
    final remaining = deadline == null
        ? (c.data.settings['restRemaining'] as num?)?.toInt()
        : (deadline.difference(DateTime.now()).inMilliseconds / 1000)
              .ceil()
              .clamp(0, 86400);
    final preset =
        (c.data.settings['restPresetSeconds'] as num?)?.toInt() ??
        (session.exercises.firstOrNull?.data['restSeconds'] as num?)?.toInt() ??
        90;
    final body = PageBody(
      title: session.active ? '正在训练' : '训练详情',
      subtitle: session.title,
      children: [
        Card(
          key: const ValueKey('workout-summary'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.paused ? '训练已暂停' : '训练计时'),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          clock(session.duration(DateTime.now()).inSeconds),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('实际完成'),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          text: '${session.completedSets}',
                          children: [
                            TextSpan(
                              text: ' 组',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (session.active)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => runAction(context, () => c.pause(session.id)),
                icon: Icon(session.paused ? Icons.play_arrow : Icons.pause),
                label: Text(session.paused ? '继续训练' : '暂停训练'),
              ),
              FilledButton(
                onPressed: finishing ? null : () => finish(context, c, session),
                child: const Text('结束训练'),
              ),
            ],
          ),
        if (session.active)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    remaining == null
                        ? '组间休息'
                        : remaining == 0
                        ? '休息结束'
                        : '休息 ${clock(remaining)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (reminderStatus != null) Text(reminderStatus!.message),
                  Text('完成组后沿用 $preset 秒；点时长可立即开始'),
                  Wrap(
                    spacing: 8,
                    children: [60, 90, 120]
                        .map(
                          (s) => ChoiceChip(
                            label: Text('$s 秒'),
                            selected: preset == s,
                            onSelected: (_) => runAction(
                              context,
                              () => setRest(c, s, preset: true),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final text = await askText(context, '休息秒数（1–86400）');
                          if (!context.mounted) return;
                          final seconds = int.tryParse(text ?? '');
                          if (seconds != null &&
                              seconds > 0 &&
                              seconds <= 86400) {
                            await runAction(
                              context,
                              () => setRest(c, seconds, preset: true),
                            );
                          } else if (text != null && mounted) {
                            restMessage('请输入 1–86400 的整秒数');
                          }
                        },
                        child: const Text('自定义'),
                      ),
                      if (remaining != null && remaining > 0) ...[
                        TextButton(
                          onPressed: () => runAction(context, () async {
                            if (deadline == null) {
                              await setRest(c, remaining);
                            } else {
                              await c.change((d) {
                                d.settings['restDeadline'] = null;
                                d.settings['restRemaining'] = remaining;
                              });
                              try {
                                await ref.read(remindersProvider).cancel();
                              } catch (_) {
                                restMessage('系统提醒未能取消，请检查通知设置');
                              }
                            }
                          }),
                          child: Text(deadline == null ? '继续' : '暂停'),
                        ),
                        TextButton(
                          onPressed: () => runAction(context, () async {
                            if (deadline == null) {
                              await c.change(
                                (d) => d.settings['restRemaining'] =
                                    remaining + 30,
                              );
                            } else {
                              await setRest(c, remaining + 30);
                            }
                          }),
                          child: const Text('+30 秒'),
                        ),
                        TextButton(
                          onPressed: () =>
                              runAction(context, () => setRest(c, null)),
                          child: const Text('结束休息'),
                        ),
                      ],
                      TextButton(
                        onPressed: enableReminders,
                        child: Text(
                          reminderStatus?.initializationFailed == true
                              ? '重试提醒'
                              : '后台提醒设置',
                        ),
                      ),
                      TextButton(
                        onPressed: () => runAction(
                          context,
                          () => ref
                              .read(remindersProvider)
                              .openBackgroundSettings(),
                        ),
                        child: const Text('后台运行设置'),
                      ),
                    ],
                  ),
                  const Text(
                    '若切到其他应用后不提醒，请在耗电管理中允许本应用后台运行。',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        if (session.active)
          LayoutBuilder(
            builder: (context, box) {
              final width =
                  box.maxWidth <
                      MediaQuery.textScalerOf(context).scale(96) * 2 + 104
                  ? box.maxWidth
                  : (box.maxWidth - 8) / 2;
              return Wrap(
                key: const ValueKey('workout-add-actions'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: OutlinedButton.icon(
                      onPressed: session.exercises.any((e) => !e.skipped)
                          ? () => runAction(
                              context,
                              () => chooseSetTarget(c, session),
                            )
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('新增一组'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final e = await pickExercise(context);
                        if (e != null && context.mounted) {
                          await runAction(
                            context,
                            () => c.addExercise(session.id, e),
                          );
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('添加动作'),
                    ),
                  ),
                ],
              );
            },
          ),
        if (session.exercises.isEmpty)
          const EmptyState(message: '添加第一个动作，开始记录'),
        ...session.exercises.indexed.toList().reversed.map((pair) {
          final i = pair.$1, move = pair.$2;
          final previous =
              c.data.sessions
                  .where(
                    (s) =>
                        s.id != session.id &&
                        !s.deleted &&
                        !s.active &&
                        s.startedAt.isBefore(session.startedAt),
                  )
                  .toList()
                ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
          final last = previous
              .expand((s) => s.exercises)
              .where((e) => e.data['exerciseId'] == move.data['exerciseId'])
              .firstOrNull;
          return Column(
            key: ValueKey('workout-move-${move.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    '${i + 1}. ${move.exercise.name}${move.skipped ? ' · 已跳过' : ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    tooltip: '上移动作',
                    onPressed: i == session.exercises.length - 1
                        ? null
                        : () => runAction(
                            context,
                            () => c.updateSession(session.id, (s) {
                              final list = s.data['exercises'] as List;
                              final index = list.indexWhere(
                                (e) => e['id'] == move.id,
                              );
                              final visible = s.exercises;
                              final position = visible.indexWhere(
                                (e) => e.id == move.id,
                              );
                              final neighborId = visible[position + 1].id;
                              final neighborIndex = list.indexWhere(
                                (e) => e['id'] == neighborId,
                              );
                              final item = list[index];
                              list[index] = list[neighborIndex];
                              list[neighborIndex] = item;
                            }),
                          ),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  TextButton(
                    onPressed: () => runAction(
                      context,
                      () => c.updateSession(session.id, (s) {
                        s.exercises
                                .firstWhere((e) => e.id == move.id)
                                .data['skipped'] =
                            !move.skipped;
                      }),
                    ),
                    child: Text(move.skipped ? '取消跳过' : '跳过后续组'),
                  ),
                ],
              ),
              Text(kindLabels[move.exercise.kind.index]),
              if (last != null)
                Text(
                  '上次：${last.sets.where((s) => s.completed).map((s) => move.exercise.kind == LoadKind.dumbbell
                      ? '${s.weight ?? '—'}kg × 左${s.value('leftReps') ?? 0}/右${s.value('rightReps') ?? 0}'
                      : move.exercise.kind == LoadKind.cardio
                      ? '${s.seconds ?? 0}秒'
                      : '${s.weight ?? s.value('assistance') ?? '—'}kg × ${s.reps ?? 0}').join('，')}',
                ),
              // Number in stored order, then reverse only the presentation.
              // New/copy groups stay newest-first without rebinding row state.
              ...move.sets.indexed.toList().reversed.map(
                (p) => WorkoutSetRow(
                  key: ValueKey(p.$2.id),
                  set: p.$2,
                  kind: move.exercise.kind,
                  index: p.$1,
                  enabled: !move.skipped && !session.paused,
                  onValidityChanged: (valid) {
                    if (mounted) {
                      setState(() {
                        if (valid) {
                          invalidSets.remove(p.$2.id);
                        } else {
                          invalidSets.add(p.$2.id);
                        }
                      });
                    }
                  },
                  save: (values) =>
                      c.editSet(session.id, move.id, p.$2.id, values),
                  complete: () async {
                    await c.completeSet(session.id, move.id, p.$2.id);
                    if (session.active) {
                      await setRest(c, restSeconds(c, move));
                    }
                  },
                  remove: () => c.editSet(session.id, move.id, p.$2.id, {
                    'deleted': true,
                  }),
                  copy: () => c.updateSession(session.id, (s) {
                    final target = s.exercises.firstWhere(
                      (e) => e.id == move.id,
                    );
                    (target.data['sets'] as List).add(
                      p.$2.duplicate().toJson(),
                    );
                  }),
                ),
              ),
              if (!session.active)
                OutlinedButton.icon(
                  onPressed: move.skipped
                      ? null
                      : () => runAction(
                          context,
                          () => appendSet(c, session.id, move.id),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('新增一组'),
                ),
            ],
          );
        }),
        if (!session.active)
          OutlinedButton.icon(
            onPressed: () async {
              final e = await pickExercise(context);
              if (e != null && context.mounted) {
                await runAction(context, () => c.addExercise(session.id, e));
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('添加动作'),
          ),
        if (!session.active) ...[
          OutlinedButton(
            onPressed: () => finish(context, c, session, editing: true),
            child: const Text('编辑训练信息'),
          ),
          Text(
            '整体感受：${session.data['feeling'] ?? '未填写'}\n恢复备注：${session.data['recoveryNote'] ?? '未填写'}',
          ),
          OutlinedButton(
            onPressed: () async {
              final name = await askText(
                context,
                '复制为模板',
                initial: session.title,
              );
              if (name != null) {
                await c.change(
                  (d) => d.templates.add(
                    WorkoutTemplate.create(name, session.exercises).freshCopy(),
                  ),
                );
              }
            },
            child: const Text('复制为模板'),
          ),
        ],
        if (c.error != null) ErrorState(message: c.error!),
        const Text('编辑会及时保存。离开页面不等于结束训练。'),
      ],
    );
    final nextMove = session.exercises
        .where((e) => !e.skipped && e.sets.any((s) => !s.completed))
        .firstOrNull;
    final nextSet = nextMove?.sets.where((s) => !s.completed).firstOrNull;
    return Column(
      children: [
        Expanded(child: body),
        if (session.active && remaining != null && remaining > 0)
          Padding(
            key: const ValueKey('rest-quick-controls'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${deadline == null ? "休息已暂停" : "休息"} ${clock(remaining)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('rest-quick-pause'),
                  tooltip: deadline == null ? '继续休息' : '暂停休息',
                  onPressed: () => runAction(context, () async {
                    if (deadline == null) {
                      await setRest(c, remaining);
                    } else {
                      await c.change((d) {
                        d.settings['restDeadline'] = null;
                        d.settings['restRemaining'] = remaining;
                      });
                      await ref.read(remindersProvider).cancel();
                    }
                  }),
                  icon: Icon(deadline == null ? Icons.play_arrow : Icons.pause),
                ),
                TextButton(
                  key: const ValueKey('rest-skip'),
                  onPressed: () => runAction(context, () => setRest(c, null)),
                  child: const Text('跳过'),
                ),
              ],
            ),
          ),
        if (session.active && nextMove != null && nextSet != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mainError != null)
                    Text(
                      mainError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton.icon(
                    onPressed:
                        completing ||
                            session.paused ||
                            invalidSets.contains(nextSet.id)
                        ? null
                        : () async {
                            setState(() {
                              completing = true;
                              mainError = null;
                            });
                            try {
                              await c.completeSet(
                                session.id,
                                nextMove.id,
                                nextSet.id,
                              );
                              await setRest(c, restSeconds(c, nextMove));
                            } catch (e) {
                              if (mounted) {
                                setState(
                                  () => mainError = e is FormatException
                                      ? e.message
                                      : '保存失败，请重试',
                                );
                              }
                            }
                            if (mounted) setState(() => completing = false);
                          },
                    icon: const Icon(Icons.check),
                    label: Text(
                      completing ? '保存中…' : '完成下一组 · ${nextMove.exercise.name}',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> finish(
    BuildContext context,
    AppController c,
    Session s, {
    bool editing = false,
  }) async {
    var feeling = s.data['feeling'] as String?;
    final note = TextEditingController(
      text: s.data['recoveryNote'] as String? ?? '',
    );
    final accepted = await showEditorialDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(editing ? '编辑训练信息' : '结束本次训练？'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${s.completedSets} 组已完成，未完成组不计入实际完成量。'),
                DropdownButton<String>(
                  value: feeling,
                  hint: const Text('整体感受（可选）'),
                  items: ['轻松', '适中', '吃力', '接近力竭']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => refresh(() => feeling = v),
                ),
                LabeledTextField(
                  controller: note,
                  label: '恢复备注（可选）',
                  maxLines: null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(editing ? '取消' : '继续练'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(editing ? '保存修改' : '结束并保存'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      setState(() => finishing = true);
      await runAction(this.context, () async {
        if (editing) {
          await c.updateSession(s.id, (session) {
            session.data['feeling'] = feeling;
            session.data['recoveryNote'] = note.text.isEmpty ? null : note.text;
          });
          return;
        }
        await c.finish(
          s.id,
          feeling: feeling,
          note: note.text.isEmpty ? null : note.text,
        );
        await setRest(c, null);
        if (context.mounted) context.go('/history/${s.id}');
      });
      if (mounted) setState(() => finishing = false);
    }
    Future.delayed(const Duration(seconds: 1), note.dispose);
  }
}

extension on WorkoutTemplate {
  WorkoutTemplate freshCopy() => WorkoutTemplate.create(name, freshExercises());
}
