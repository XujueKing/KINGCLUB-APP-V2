import 'package:flutter/material.dart';

import '../../auth/data/auth_repository_provider.dart';
import '../data/party_publisher_workspace.dart';
import '../data/secure_together_publication.dart';
import 'reservation_components.dart';
import 'together_artwork_upload_page.dart';
import 'together_party_create_page.dart';

/// Loads the entire wizard once; venue, package and artwork pickers reuse it.
class PartyPublisherPage extends StatefulWidget {
  const PartyPublisherPage({
    super.key,
    required this.storeRef,
    this.contractRef,
    this.publication,
  });
  final String storeRef;
  final String? contractRef;
  final SecureTogetherPublication? publication;
  @override
  State<PartyPublisherPage> createState() => _PartyPublisherState();
}

class _PartyPublisherState extends State<PartyPublisherPage> {
  late final publication =
      widget.publication ??
      SecureTogetherPublication.secure(kingclubApiBaseUrl);
  PartyPublisherWorkspace? _data;
  String? _error;
  bool _busy = true;
  String get publisherType =>
      widget.contractRef == null ? 'official' : 'collaborator';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await publication.workspace(
        storeRef: widget.storeRef,
        publisherType: publisherType,
        contractRef: widget.contractRef,
      );
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final data = _data;
    if (data == null) {
      return reservationScaffold(
        c,
        title: reservationText(
          c,
          '发布AA邀请|Publish AA invitation|發布AA邀請|เผยแพร่คำเชิญ AA',
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _busy
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error ?? '暂时无法读取发布资料'),
                      const SizedBox(height: 20),
                      reservationButton(
                        reservationText(c, '重新读取|Reload|重新讀取|โหลดใหม่'),
                        _load,
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
    return TogetherPartyCreatePage(
      cityCode: data.store.cityCode,
      cityName: data.cityName,
      onBack: () => Navigator.of(c).pop(),
      publisherType: publisherType,
      contractRef: widget.contractRef,
      contractStartsAt: data.contractStartsAt,
      contractEndsAt: data.contractEndsAt,
      initialStore: data.store,
      initialTable: widget.contractRef == null ? null : data.tablesList.single,
      stores: data,
      publication: publication,
      loadPackages: (_) async => data.packages,
      loadLibrary: () async => data.artwork,
      uploadArtwork: () async {
        await Navigator.of(c).push(
          MaterialPageRoute<void>(
            builder: (_) => TogetherArtworkUploadPage(repository: publication),
          ),
        );
        return null;
      },
    );
  }
}
