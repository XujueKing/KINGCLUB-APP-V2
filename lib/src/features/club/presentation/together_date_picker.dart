import 'package:flutter/material.dart';

import 'legacy_club_components.dart';

/// Choose.wxss geometry; the fixed calendar is outside the scrolling dates.
class TogetherDateStrip extends StatefulWidget {
  const TogetherDateStrip({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDate,
    required this.onSelected,
  });

  final DateTime firstDate, lastDate, selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  State<TogetherDateStrip> createState() => _TogetherDateStripState();
}

int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

class _TogetherDateStripState extends State<TogetherDateStrip> {
  final _scroll = ScrollController();
  double _extent = 60;

  @override
  void didUpdateWidget(TogetherDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelection());
    }
  }

  void _revealSelection() {
    if (!mounted || !_scroll.hasClients) return;
    final start = _daysBetween(widget.firstDate, widget.selectedDate) * _extent;
    final end = start + _extent;
    final position = _scroll.position;
    double target = position.pixels;
    if (start < target) target = start;
    if (end > target + position.viewportDimension) {
      target = end - position.viewportDimension;
    }
    _scroll.animateTo(
      target.clamp(0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _calendar() async {
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF171512),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => TogetherCalendarSheet(
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        selectedDate: widget.selectedDate,
      ),
    );
    if (mounted && selected != null) widget.onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final unit = MediaQuery.sizeOf(context).width / 750;
    final scaler = MediaQuery.textScalerOf(context);
    final width =
        (80 * unit).clamp(40.0, double.infinity) *
        (scaler.scale(28 * unit) / (28 * unit)).clamp(1.0, double.infinity);
    _extent = width + 40 * unit;
    final textHeight =
        scaler.scale(22 * unit) * 1.4 +
        4 * unit +
        scaler.scale(28 * unit) * 1.4;
    final height = (textHeight.ceilToDouble() + 2).clamp(48.0, double.infinity);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * unit, vertical: 30 * unit),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: ListView.builder(
                key: const ValueKey('together-date-scroll'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                itemExtent: _extent,
                itemCount: _daysBetween(widget.firstDate, widget.lastDate) + 1,
                itemBuilder: (_, index) {
                  final date = DateTime(
                    widget.firstDate.year,
                    widget.firstDate.month,
                    widget.firstDate.day + index,
                  );
                  final selected = DateUtils.isSameDay(
                    date,
                    widget.selectedDate,
                  );
                  final color = selected ? Colors.black : legacyGold;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: '${date.year}年${date.month}月${date.day}日',
                    child: InkWell(
                      key: ValueKey('together-date-$index'),
                      onTap: () => widget.onSelected(date),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 20 * unit),
                        decoration: BoxDecoration(
                          color: selected ? legacyGold : Colors.transparent,
                          borderRadius: BorderRadius.circular(8 * unit),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              const [
                                '周一',
                                '周二',
                                '周三',
                                '周四',
                                '周五',
                                '周六',
                                '周日',
                              ][date.weekday - 1],
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 22 * unit,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                                color: color,
                              ),
                            ),
                            SizedBox(height: 4 * unit),
                            Text(
                              '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 28 * unit,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              width: 52,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0x22C9B69E))),
              ),
              child: IconButton(
                key: const ValueKey('together-calendar-open'),
                tooltip: '选择日期',
                onPressed: _calendar,
                padding: EdgeInsets.zero,
                icon: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 25,
                      color: legacyGold,
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: legacyGold,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TogetherCalendarSheet extends StatelessWidget {
  const TogetherCalendarSheet({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDate,
  });
  final DateTime firstDate, lastDate, selectedDate;

  @override
  Widget build(BuildContext context) {
    // Start with the selected month; all earlier selectable months remain above.
    final monthCount =
        (lastDate.year - firstDate.year) * 12 +
        lastDate.month -
        firstDate.month +
        1;
    final selectedMonth =
        (selectedDate.year - firstDate.year) * 12 +
        selectedDate.month -
        firstDate.month;
    final fontScale = MediaQuery.textScalerOf(context).scale(18) / 18;
    final cellHeight = (52 * fontScale).clamp(52.0, double.infinity);
    final monthHeight = 56 + 6 * cellHeight;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .87,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 60,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    '选择日期',
                    style: TextStyle(
                      color: legacyGold,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    child: IconButton(
                      key: const ValueKey('together-calendar-close'),
                      tooltip: '关闭日历',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: legacyGold),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  for (final day in ['日', '一', '二', '三', '四', '五', '六'])
                    Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 14,
                            color: day == '日' || day == '六'
                                ? legacyGold
                                : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x22C9B69E)),
            Expanded(
              child: _CalendarMonths(
                firstDate: firstDate,
                lastDate: lastDate,
                selectedDate: selectedDate,
                monthCount: monthCount,
                initialMonth: selectedMonth,
                monthHeight: monthHeight,
                cellHeight: cellHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarMonths extends StatefulWidget {
  const _CalendarMonths({
    required this.firstDate,
    required this.lastDate,
    required this.selectedDate,
    required this.monthCount,
    required this.initialMonth,
    required this.monthHeight,
    required this.cellHeight,
  });
  final DateTime firstDate, lastDate, selectedDate;
  final int monthCount, initialMonth;
  final double monthHeight, cellHeight;
  @override
  State<_CalendarMonths> createState() => _CalendarMonthsState();
}

class _CalendarMonthsState extends State<_CalendarMonths> {
  late final _scroll = ScrollController(
    initialScrollOffset: widget.initialMonth * widget.monthHeight,
  );
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const ValueKey('together-calendar-months'),
    controller: _scroll,
    itemExtent: widget.monthHeight,
    itemCount: widget.monthCount,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemBuilder: (_, index) {
      final month = DateTime(
        widget.firstDate.year,
        widget.firstDate.month + index,
      );
      final leading = month.weekday % 7;
      final days = DateUtils.getDaysInMonth(month.year, month.month);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${month.year}年${month.month}月',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          for (var row = 0; row < 6; row++)
            SizedBox(
              height: widget.cellHeight,
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _day(
                        context,
                        month,
                        row * 7 + col - leading + 1,
                        days,
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _day(BuildContext context, DateTime month, int number, int days) {
    if (number < 1 || number > days) return const SizedBox.shrink();
    final date = DateTime(month.year, month.month, number);
    final enabled =
        !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
    final selected = DateUtils.isSameDay(date, widget.selectedDate);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '${date.year}年${date.month}月${date.day}日',
      child: InkWell(
        key: ValueKey(
          'together-calendar-${date.year}-${date.month}-${date.day}',
        ),
        onTap: enabled ? () => Navigator.pop(context, date) : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.all(2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? legacyGold : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 18,
              height: 1.2,
              color: !enabled
                  ? Colors.white24
                  : selected
                  ? Colors.black
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
