import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../data/together_play.dart';
import 'together_seat_cards.dart';

Future<TogetherSeatChoice?> showTogetherSeatPicker(
  BuildContext context,
  TogetherParty party, {
  bool changing = false,
}) => Navigator.of(context).push<TogetherSeatChoice>(
  MaterialPageRoute(
    builder: (_) => _SeatPicker(party: party, changing: changing),
  ),
);

class _SeatPicker extends StatefulWidget {
  const _SeatPicker({required this.party, required this.changing});
  final TogetherParty party;
  final bool changing;
  @override
  State<_SeatPicker> createState() => _SeatPickerState();
}

class _SeatPickerState extends State<_SeatPicker> {
  TogetherSeatChoice? choice = const TogetherSeatChoice.random();
  bool random = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: kingAppBar(
      context: context,
      title: Text(widget.changing ? '申请调座' : '选择座位'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.party.theme,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('系统随机')),
            ButtonSegment(value: false, label: Text('自己选座')),
          ],
          selected: {random},
          onSelectionChanged: (v) => setState(() {
            random = v.first;
            choice = random ? const TogetherSeatChoice.random() : null;
          }),
        ),
        const SizedBox(height: 12),
        const Text(
          '上排男士，下排女士；点击已报名会员头像可查看公开资料。',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 12),
        TogetherSeatCards(
          party: widget.party,
          choice: choice,
          onSelect: random ? null : (v) => setState(() => choice = v),
        ),
        const Text(
          '所选座位以付款时确认结果为准。分配后调整需申请，批准前保留原座位。',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: choice == null
              ? null
              : () => Navigator.pop(context, choice),
          child: Text(widget.changing ? '提交调座申请' : '确认选座，继续报名'),
        ),
      ],
    ),
  );
}
