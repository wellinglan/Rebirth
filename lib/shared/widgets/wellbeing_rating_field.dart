import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';

abstract final class WellbeingRatingPalette {
  static const low = Color(0xFFE4A0A0);
  static const middle = Color(0xFFE2C267);
  static const high = Color(0xFF7DB68A);
  static const inactive = Color(0xFFFDFDFC);
  static const outline = Color(0xFFCCD3D0);
}

Color wellbeingRatingColor(
  int value, {
  int minimumValue = 1,
  int maximumValue = 10,
}) {
  assert(minimumValue < maximumValue);
  final normalized =
      ((value.clamp(minimumValue, maximumValue) - minimumValue) /
      (maximumValue - minimumValue));
  if (normalized <= 0.5) {
    return Color.lerp(
      WellbeingRatingPalette.low,
      WellbeingRatingPalette.middle,
      normalized * 2,
    )!;
  }
  return Color.lerp(
    WellbeingRatingPalette.middle,
    WellbeingRatingPalette.high,
    (normalized - 0.5) * 2,
  )!;
}

double wellbeingRatingFraction(
  int? value, {
  int minimumValue = 1,
  int maximumValue = 10,
}) {
  if (value == null) return 0;
  return (value.clamp(minimumValue, maximumValue) - minimumValue) /
      (maximumValue - minimumValue);
}

class WellbeingRatingField extends StatefulWidget {
  const WellbeingRatingField({
    required this.label,
    required this.icon,
    required this.value,
    required this.description,
    required this.descriptionHint,
    required this.onScoreChanged,
    required this.onDescriptionChanged,
    super.key,
    this.minimumValue = 1,
    this.maximumValue = 10,
  }) : assert(minimumValue < maximumValue),
       assert(value == null || value >= minimumValue),
       assert(value == null || value <= maximumValue);

  final String label;
  final IconData icon;
  final int? value;
  final String description;
  final String descriptionHint;
  final int minimumValue;
  final int maximumValue;
  final ValueChanged<int?> onScoreChanged;
  final ValueChanged<String> onDescriptionChanged;

  @override
  State<WellbeingRatingField> createState() => _WellbeingRatingFieldState();
}

class _WellbeingRatingFieldState extends State<WellbeingRatingField> {
  late int? _score = widget.value;
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.description);
  late final FocusNode _sliderFocusNode = FocusNode(
    debugLabel: '${widget.label}评分',
    onKeyEvent: _handleSliderKey,
  );

  @override
  void didUpdateWidget(covariant WellbeingRatingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _score) {
      _score = widget.value;
    }
    if (widget.description != oldWidget.description &&
        widget.description != _descriptionController.text) {
      _descriptionController.value = TextEditingValue(
        text: widget.description,
        selection: TextSelection.collapsed(offset: widget.description.length),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _sliderFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final scoreText = score == null ? '未记录' : '$score / ${widget.maximumValue}';
    final targetColor = score == null
        ? WellbeingRatingPalette.low
        : wellbeingRatingColor(
            score,
            minimumValue: widget.minimumValue,
            maximumValue: widget.maximumValue,
          );
    final motionDuration = AppMotion.responsive(context, AppMotion.quick);
    return Semantics(
      key: ValueKey('${widget.label}Semantics'),
      container: true,
      label: '${widget.label}，$scoreText',
      child: DecoratedBox(
        key: ValueKey('${widget.label}RatingSurface'),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          widget.icon,
                          key: ValueKey('${widget.label}Icon'),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        widget.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        scoreText,
                        key: ValueKey('${widget.label}ScoreText'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: score == null
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (score != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          key: ValueKey('${widget.label}Clear'),
                          tooltip: '清空${widget.label}评分',
                          onPressed: () => _emitScore(null),
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TweenAnimationBuilder<Color?>(
                key: ValueKey('${widget.label}ColorAnimation'),
                tween: ColorTween(end: targetColor),
                duration: motionDuration,
                builder: (context, animatedColor, _) {
                  final activeColor = animatedColor ?? targetColor;
                  return Semantics(
                    key: ValueKey('${widget.label}SliderSemantics'),
                    label: '调整${widget.label}评分',
                    value: score == null
                        ? '未记录'
                        : '$score 分，共 ${widget.maximumValue} 分',
                    increasedValue: _semanticAdjustedValue(1),
                    decreasedValue: _semanticAdjustedValue(-1),
                    onIncrease: () => _adjustScore(1),
                    onDecrease: score == null ? null : () => _adjustScore(-1),
                    child: ExcludeSemantics(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 12,
                          trackShape: _WellbeingTrackShape(
                            activeColor: activeColor,
                            showActive: score != null,
                          ),
                          thumbColor: Colors.white,
                          thumbShape: score == null
                              ? SliderComponentShape.noThumb
                              : _WellbeingThumbShape(borderColor: activeColor),
                          overlayColor: activeColor.withValues(alpha: 0.16),
                          tickMarkShape: const RoundSliderTickMarkShape(
                            tickMarkRadius: 2,
                          ),
                          activeTickMarkColor: Colors.white.withValues(
                            alpha: 0.92,
                          ),
                          inactiveTickMarkColor: Theme.of(
                            context,
                          ).colorScheme.outline,
                        ),
                        child: Slider(
                          key: ValueKey('${widget.label}Slider'),
                          focusNode: _sliderFocusNode,
                          value: (score ?? widget.minimumValue).toDouble(),
                          min: widget.minimumValue.toDouble(),
                          max: widget.maximumValue.toDouble(),
                          divisions: widget.maximumValue - widget.minimumValue,
                          label: score?.toString(),
                          onChanged: (raw) => _emitScore(raw.round()),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${widget.minimumValue}'),
                    Text('${widget.maximumValue}'),
                  ],
                ),
              ),
              if (score == null) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: ValueKey('${widget.label}Start'),
                    onPressed: _startFromMiddle,
                    icon: const Icon(Icons.touch_app_outlined),
                    label: const Text('开始记录'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: ValueKey('${widget.label}Description'),
                controller: _descriptionController,
                maxLength: 80,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '${widget.label}描述（可选）',
                  hintText: widget.descriptionHint,
                  counterText: '',
                ),
                onChanged: widget.onDescriptionChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleSliderKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      return _handleAdjustment(1);
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      return _handleAdjustment(-1);
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      return _handleActivation();
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleAdjustment(int delta) {
    _adjustScore(delta);
    return KeyEventResult.handled;
  }

  KeyEventResult _handleActivation() {
    if (_score == null) _startFromMiddle();
    return KeyEventResult.handled;
  }

  void _startFromMiddle() {
    _emitScore((widget.minimumValue + widget.maximumValue) ~/ 2);
    _sliderFocusNode.requestFocus();
  }

  void _adjustScore(int delta) {
    final score = _score;
    if (score == null) {
      if (delta > 0) _emitScore(widget.minimumValue);
      return;
    }
    _emitScore((score + delta).clamp(widget.minimumValue, widget.maximumValue));
  }

  void _emitScore(int? next) {
    final normalized = next
        ?.clamp(widget.minimumValue, widget.maximumValue)
        .toInt();
    setState(() => _score = normalized);
    widget.onScoreChanged(normalized);
  }

  String? _semanticAdjustedValue(int delta) {
    final score = _score;
    if (score == null) {
      return delta > 0 ? '${widget.minimumValue} 分' : null;
    }
    final next = (score + delta).clamp(
      widget.minimumValue,
      widget.maximumValue,
    );
    return '$next 分';
  }
}

class _WellbeingTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _WellbeingTrackShape({
    required this.activeColor,
    required this.showActive,
  });

  final Color activeColor;
  final bool showActive;

  @override
  bool get isRounded => true;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final radius = Radius.circular(track.height / 2);
    final canvas = context.canvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, radius),
      Paint()..color = WellbeingRatingPalette.inactive,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, radius),
      Paint()
        ..color = WellbeingRatingPalette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    if (!showActive) return;
    final isLtr = textDirection == TextDirection.ltr;
    final activeRect = isLtr
        ? Rect.fromLTRB(
            track.left,
            track.top,
            (thumbCenter.dx + track.height / 2).clamp(track.left, track.right),
            track.bottom,
          )
        : Rect.fromLTRB(
            (thumbCenter.dx - track.height / 2).clamp(track.left, track.right),
            track.top,
            track.right,
            track.bottom,
          );
    canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, radius),
      Paint()..color = activeColor,
    );
  }
}

class _WellbeingThumbShape extends SliderComponentShape {
  const _WellbeingThumbShape({required this.borderColor});

  final Color borderColor;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(24, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final path = Path()..addOval(Rect.fromCircle(center: center, radius: 11));
    context.canvas.drawShadow(path, Colors.black, 2, true);
    context.canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    context.canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
