import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../contacts/presentation/public_member_page.dart';
import '../data/together_play.dart';

class TogetherMemberAvatar extends StatelessWidget {
  const TogetherMemberAvatar({
    super.key,
    this.member,
    this.gender = TogetherGender.unspecified,
    this.size = 28,
    this.onTap,
  });
  final TogetherParticipant? member;
  final TogetherGender gender;
  final double size;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final sex = member?.gender != TogetherGender.unspecified && member != null
        ? member!.gender
        : gender;
    final fallback = Center(
      child: sex == TogetherGender.unspecified
          ? Icon(
              Icons.person_outline,
              size: size * .65,
              color: const Color(0xFF9C277E),
            )
          : Image.asset(
              sex == TogetherGender.male
                  ? 'assets/legacy/aa/man2.png'
                  : 'assets/legacy/aa/woman.png',
              height: size * .65,
            ),
    );
    final avatar = member?.avatar;
    final image = member?.avatarBytes != null
        ? Image.memory(
            member!.avatarBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallback,
          )
        : avatar == null || avatar.isEmpty
        ? fallback
        : avatar.startsWith('assets/')
        ? Image.asset(
            avatar,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : CachedMediaImage(
            avatar,
            width: size,
            height: size,
            placeholder: fallback,
            errorBuilder: (_, _, _) => fallback,
          );
    return Semantics(
      label: member == null ? '空位' : member!.name,
      child: GestureDetector(
        onTap:
            onTap ??
            (member?.account == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PublicMemberPage(account: member!.account!),
                    ),
                  )),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: size,
            height: size,
            child: ColoredBox(
              color: member == null
                  ? const Color(0x448F6782)
                  : const Color(0xFFFFD1EC),
              child: image,
            ),
          ),
        ),
      ),
    );
  }
}

class TogetherAttendeeGrid extends StatelessWidget {
  const TogetherAttendeeGrid({super.key, required this.party});
  final TogetherParty party;
  @override
  Widget build(BuildContext context) {
    final people = party.participants.take(10).toList();
    final me = party.participants.where((p) => p.isMe).firstOrNull;
    if (me != null && !people.contains(me) && people.isNotEmpty) {
      people[people.length - 1] = me;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        2,
        (row) => Padding(
          padding: EdgeInsets.only(top: row == 0 ? 0 : 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (col) {
              final i = row * 5 + col;
              return Padding(
                padding: EdgeInsets.only(left: col == 0 ? 0 : 6),
                child: i < people.length
                    ? TogetherMemberAvatar(member: people[i])
                    : const SizedBox(width: 28, height: 28),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class TogetherSeatCards extends StatelessWidget {
  const TogetherSeatCards({
    super.key,
    required this.party,
    this.choice,
    this.onSelect,
  });
  final TogetherParty party;
  final TogetherSeatChoice? choice;
  final ValueChanged<TogetherSeatChoice>? onSelect;

  List<int> _rowSeats(TogetherActivityTable table, TogetherGender gender) {
    if (table.genderRestricted) {
      return gender == TogetherGender.male
          ? List.generate(table.maleSeats, (i) => i)
          : List.generate(table.femaleSeats, (i) => table.maleSeats + i);
    }
    final occupied = table.participants.map((p) => p.seatIndex).toSet();
    final vacant = List.generate(table.capacity, (i) => i)
        .where((i) => !occupied.contains(i) && !table.reservedSeats.contains(i))
        .toList();
    final split = (vacant.length / 2).ceil();
    return [
      ...table.participants
          .where((p) => p.gender == gender)
          .map((p) => p.seatIndex!),
      ...table.reservedSeats.where(
        (i) => gender == TogetherGender.male
            ? i < table.maleSeats
            : i >= table.maleSeats,
      ),
      ...(gender == TogetherGender.male
          ? vacant.take(split)
          : vacant.skip(split)),
    ];
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final table in party.tables)
        Card(
          color: const Color(0xFF302B30),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${table.name} · ${table.participants.length}/${table.capacity}人',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final gender in [
                  TogetherGender.male,
                  TogetherGender.female,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(_rowSeats(table, gender).length, (
                        i,
                      ) {
                        final index = _rowSeats(table, gender)[i];
                        final member = table.participants
                            .where((p) => p.seatIndex == index)
                            .firstOrNull;
                        final selected =
                            choice?.tableRef == table.ref &&
                            choice?.seatIndex == index;
                        final canPick =
                            onSelect != null &&
                            member == null &&
                            !table.reservedSeats.contains(index) &&
                            (!table.genderRestricted ||
                                party.myGender == gender);
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Opacity(
                              opacity: table.reservedSeats.contains(index)
                                  ? .35
                                  : 1,
                              child: TogetherMemberAvatar(
                                size: 32,
                                gender: gender,
                                member: member,
                                onTap: canPick
                                    ? () => onSelect!(
                                        TogetherSeatChoice.selected(
                                          table.ref,
                                          index,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
