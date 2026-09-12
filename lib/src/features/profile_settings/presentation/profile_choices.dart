import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../onboarding/presentation/onboarding_components.dart';

const styleChoices = [
  PreferenceOption(id: 'formal_cocktail', label: '高级酒会小礼服'),
  PreferenceOption(id: 'korean_modern', label: '韩式现代时尚风'),
  PreferenceOption(id: 'fresh', label: '小清新'),
  PreferenceOption(id: 'soft_glam', label: '纯欲风'),
  PreferenceOption(id: 'lolita', label: '洛丽塔风'),
  PreferenceOption(id: 'hanfu', label: '国风汉服'),
  PreferenceOption(id: 'cosplay', label: 'COSPLAY'),
  PreferenceOption(id: 'rugged', label: '痞帅风'),
];
const musicChoices = [
  PreferenceOption(id: 'house', label: 'HOUSE'),
  PreferenceOption(id: 'techno', label: 'TECHNO'),
  PreferenceOption(id: 'bounce', label: 'BOUNCE'),
  PreferenceOption(id: 'psy_trance', label: 'PSY TRANCE'),
  PreferenceOption(id: 'trance', label: 'TRANCE'),
  PreferenceOption(id: 'hip_hop', label: 'HIP-HOP'),
  PreferenceOption(id: 'dubstep', label: 'DUBSTEP'),
  PreferenceOption(id: 'big_room', label: 'BIG ROOM'),
];
const drinkChoices = [
  PreferenceOption(id: 'whisky', label: '威士忌'),
  PreferenceOption(id: 'brandy', label: '白兰地'),
  PreferenceOption(id: 'vodka', label: '伏特加'),
  PreferenceOption(id: 'red_wine', label: '红葡萄酒'),
  PreferenceOption(id: 'sake', label: '日本清酒'),
  PreferenceOption(id: 'champagne', label: '香槟'),
  PreferenceOption(id: 'cocktail', label: '鸡尾酒'),
  PreferenceOption(id: 'beer', label: '啤酒'),
];
const eventChoices = [
  PreferenceOption(id: 'formal_ball', label: '高级小礼服舞会'),
  PreferenceOption(id: 'cosplay_ball', label: 'Cosplay 化妆舞会'),
  PreferenceOption(id: 'celebrity_meetup', label: '明星见面会'),
  PreferenceOption(id: 'creator_carnival', label: '网红狂欢舞会'),
  PreferenceOption(id: 'campus_club', label: '校园社团专场'),
  PreferenceOption(id: 'car_club', label: '车友会专场'),
  PreferenceOption(id: 'korean_fresh_party', label: '韩式小清新 Party'),
  PreferenceOption(id: 'retro_classic', label: '怀旧经典专场'),
];

const preferenceChoices = {
  'styles': styleChoices,
  'music': musicChoices,
  'drinks': drinkChoices,
  'events': eventChoices,
};
const preferenceTitles = {
  'styles': '着装风格',
  'music': '音乐类型',
  'drinks': '饮酒偏好',
  'events': '活动偏好',
};

class ProfileInterestsPage extends StatefulWidget {
  const ProfileInterestsPage({super.key, required this.initial});
  final Map<String, List<String>> initial;
  @override
  State<ProfileInterestsPage> createState() => _ProfileInterestsPageState();
}

class _ProfileInterestsPageState extends State<ProfileInterestsPage> {
  late final selected = {
    for (final key in preferenceChoices.keys) key: {...?widget.initial[key]},
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('兴趣偏好'), centerTitle: true),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                for (final key in preferenceChoices.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: PreferenceSection(
                      title: preferenceTitles[key]!,
                      options: preferenceChoices[key]!,
                      selected: selected[key]!,
                      onChanged: (id) => setState(() {
                        if (!selected[key]!.remove(id)) selected[key]!.add(id);
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, {
                for (final e in selected.entries) e.key: e.value.toList(),
              }),
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    ),
  );
}

class ProfileCityPage extends StatefulWidget {
  const ProfileCityPage({super.key});
  @override
  State<ProfileCityPage> createState() => _ProfileCityPageState();
}

class _ProfileCityPageState extends State<ProfileCityPage> {
  late final cities = rootBundle
      .loadString('assets/legacy/profile/cities.json')
      .then((value) {
        final data = jsonDecode(value) as Map<String, dynamic>;
        return [
          for (final e in data.entries)
            for (final city in e.value as List) '${e.key} · $city',
        ];
      });
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('选择城市'), centerTitle: true),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              decoration: const InputDecoration(hintText: '搜索省份或城市'),
              onChanged: (value) => setState(() => query = value.trim()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: cities,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('城市列表无法读取，请返回重试'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!
                    .where((city) => city.contains(query))
                    .toList();
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(items[index]),
                    onTap: () => Navigator.pop(context, items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Future<double?> selectProfileMeasure(
  BuildContext context, {
  required String title,
  required String unit,
  required double min,
  required double max,
  required double step,
  required double initial,
}) {
  double value = initial.clamp(min, max);
  return showModalBottomSheet<double>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 22),
              Text(
                '${value.toStringAsFixed(step < 1 ? 1 : 0)} $unit',
                style: const TextStyle(fontSize: 30),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: value > min
                        ? () => update(
                            () => value = (value - step).clamp(min, max),
                          )
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Slider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: ((max - min) / step).round(),
                      onChanged: (next) =>
                          update(() => value = (next / step).round() * step),
                    ),
                  ),
                  IconButton(
                    onPressed: value < max
                        ? () => update(
                            () => value = (value + step).clamp(min, max),
                          )
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('$min $unit'), Text('$max $unit')],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, value),
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
