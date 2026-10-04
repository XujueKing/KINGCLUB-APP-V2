import 'together_artwork_upload_page.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../home/data/home_city_catalog.dart';
import '../../home/presentation/home_city_page.dart';
import '../data/secure_together_play_repository.dart';
import '../data/secure_together_publication.dart';
import '../data/secure_together_store_repository.dart';
import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'together_booking_page.dart';
import 'together_party_create_page.dart';
import 'together_play_page.dart';
import 'together_ticket_page.dart';

class TogetherEntryPage extends StatefulWidget {
  const TogetherEntryPage({
    super.key,
    required this.onBack,
    this.initialCity,
    this.repository,
    this.restoreCity,
  });
  final VoidCallback onBack;
  final HomeCity? initialCity;
  final SecureTogetherPlayRepository? repository;
  final Future<HomeCity?> Function()? restoreCity;
  @override
  State<TogetherEntryPage> createState() => _TogetherEntryPageState();
}

class _TogetherEntryPageState extends State<TogetherEntryPage> {
  late final repository =
      widget.repository ??
      SecureTogetherPlayRepository.secure(kingclubApiBaseUrl);
  HomeCity? city;
  bool loading = true;
  String? error;
  int revision = 0;
  StreamSubscription<void>? sessionChanges;

  @override
  void initState() {
    super.initState();
    city = widget.initialCity;
    loading = city == null;
    sessionChanges = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) setState(() => revision++);
    });
    if (city == null) unawaited(_restoreCity());
  }

  Future<void> _restoreCity() async {
    try {
      if (widget.restoreCity != null) {
        final restored = await widget.restoreCity!();
        if (mounted) {
          setState(() {
            city = restored;
            loading = false;
          });
        }
        return;
      }
      final catalog = await HomeCityCatalog.load();
      final history = await const HomeCityHistory().read();
      if (!mounted) return;
      setState(() {
        city = history.isEmpty ? null : catalog.byCode[history.first];
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '城市列表暂不可用';
        });
      }
    }
  }

  Future<void> _chooseCity() async {
    try {
      final catalog = await HomeCityCatalog.load();
      if (!mounted) return;
      final selected = await Navigator.of(context).push<HomeCity>(
        MaterialPageRoute(
          builder: (_) => HomeCityPage(catalog: catalog, current: city),
        ),
      );
      if (mounted && selected != null) {
        setState(() {
          city = selected;
          error = null;
          revision++;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = '城市列表暂不可用，请重试');
    }
  }

  Future<void> _create() async {
    final selected = city!;
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (pageContext) => TogetherPartyCreatePage(
          cityCode: selected.code,
          cityName: selected.name,
          onBack: () => Navigator.pop(pageContext),
          stores: SecureTogetherStoreRepository.secure(kingclubApiBaseUrl),
          publication: SecureTogetherPublication.secure(kingclubApiBaseUrl),
          uploadArtwork: () async {
            await Navigator.of(pageContext).push<void>(
              MaterialPageRoute(
                builder: (_) => TogetherArtworkUploadPage(
                  repository: SecureTogetherPublication.secure(
                    kingclubApiBaseUrl,
                  ),
                ),
              ),
            );
            return null;
          },
        ),
      ),
    );
    if (mounted) setState(() => revision++);
  }

  Future<void> _admission(TogetherParty party) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TogetherTicketPage(
            party: party,
            removalRepository: repository,
            reload: () => repository.admission(party.ref),
          ),
        ),
      );

  @override
  void dispose() {
    sessionChanges?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = city;
    if (selected == null) {
      return LegacyClubScaffold(
        title: '一起玩',
        onBack: widget.onBack,
        showMockLabel: false,
        child: Center(
          child: loading
              ? const CircularProgressIndicator(color: legacyGold)
              : TextButton(
                  onPressed: _chooseCity,
                  child: Text(error ?? '选择城市，查看同城组局'),
                ),
        ),
      );
    }
    return TogetherPlayPage(
      key: ValueKey('${selected.code}:$revision'),
      repository: repository,
      cityCode: selected.code,
      cityName: selected.shortName,
      onBack: widget.onBack,
      onSelectCity: _chooseCity,
      onCreate: _create,
      onAdmission: _admission,
      onJoin: (party) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                TogetherBookingPage(party: party, repository: repository),
          ),
        );
        if (mounted) setState(() => revision++);
      },
    );
  }
}
