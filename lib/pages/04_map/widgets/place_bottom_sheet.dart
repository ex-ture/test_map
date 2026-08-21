import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/place.dart';
import '../../../routes/app_routes.dart';

class PlaceBottomSheet extends StatelessWidget {
  const PlaceBottomSheet({
    super.key,
    required this.place,
    required this.currentLocation,
  });

  final Place place;
  final LatLng? currentLocation;

  Future<void> _openExternalBrowser(BuildContext context) async {
    final Uri uri = Uri.parse(place.webUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
      }
    }
  }

  void _openInAppWebView(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.webview, arguments: place.webUrl);
  }

  String _buildGoogleMapsRouteUrl() {
    final String destination = '${place.latitude},${place.longitude}';
    final LatLng? location = currentLocation;

    if (location == null) {
      return 'https://www.google.com/maps/dir/?api=1&destination=$destination';
    }

    final String origin = '${location.latitude},${location.longitude}';
    return 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination';
  }

  Future<void> _openRouteInExternalApp(BuildContext context) async {
    final String routeUrl = _buildGoogleMapsRouteUrl();
    final Uri uri = Uri.parse(routeUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
      }
    }
  }

  Widget _buildActionRow({
    required BuildContext context,
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              place.description,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 4),
            Text(
              place.webUrl,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD8D8DC)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionRow(
                    context: context,
                    title: '他のアプリで開く',
                    trailing: const Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: Color(0xFF8E8E93),
                    ),
                    onTap: () => _openExternalBrowser(context),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildActionRow(
                    context: context,
                    title: 'アプリ内で開く',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Color(0xFF8E8E93),
                    ),
                    onTap: () => _openInAppWebView(context),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildActionRow(
                    context: context,
                    title: 'ルートを見る',
                    trailing: const Icon(
                      Icons.directions_rounded,
                      size: 22,
                      color: Color(0xFF8E8E93),
                    ),
                    onTap: () => _openRouteInExternalApp(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
