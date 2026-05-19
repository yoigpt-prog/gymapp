// Flutter Web-only AdSense widget using HtmlElementView + dart:ui_web.
// This file is only compiled on Flutter Web (selected via conditional export).
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/material.dart';

const String _kAdClient = 'ca-pub-5827254930319648';

/// Google AdSense display ad — Flutter Web only.
///
/// Renders a real `<ins class="adsbygoogle">` element via [HtmlElementView].
/// On non-web platforms this class is replaced by the no-op stub.
///
/// IMPORTANT: [HtmlElementView] requires a DEFINITE bounded size on both axes.
/// We use [SizedBox] (not ConstrainedBox) to guarantee a finite height,
/// otherwise Flutter's renderer throws an assertion in rendering/object.dart.
class AdSenseWidget extends StatefulWidget {
  /// AdSense ad-slot ID (10 digits).
  final String adSlot;

  /// data-ad-format value passed to AdSense.
  final String adFormat;

  /// Explicit reserved height — must be finite and positive.
  final double minHeight;

  /// Outer margin. Defaults to 16px vertical for AdSense policy spacing.
  final EdgeInsets? margin;

  const AdSenseWidget({
    Key? key,
    required this.adSlot,
    this.adFormat = 'auto',
    this.minHeight = 280,
    this.margin,
  }) : super(key: key);

  @override
  State<AdSenseWidget> createState() => _AdSenseWidgetState();
}

class _AdSenseWidgetState extends State<AdSenseWidget>
    with AutomaticKeepAliveClientMixin {
  static int _counter = 0;
  late final String _viewId;
  ScrollPosition? _scrollPosition;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Each instance gets a unique viewType — prevents double-registration errors.
    _viewId = 'adsense_${widget.adSlot}_${_counter++}';
    _registerViewFactory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    if (_scrollPosition != scrollable?.position) {
      _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
      _scrollPosition = scrollable?.position;
      _scrollPosition?.isScrollingNotifier.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final isScrolling = _scrollPosition?.isScrollingNotifier.value ?? false;
    final element = html.document.getElementById(_viewId);
    if (element != null) {
      // Disable pointer events while scrolling so the iframe doesn't swallow touches/wheel events
      // and cause the scroll to abruptly "stop".
      element.style.pointerEvents = isScrolling ? 'none' : 'auto';
    }
  }

  void _registerViewFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      // Wrapper div: must fill its parent completely.
      final container = html.DivElement()
        ..id = _viewId // Set ID so we can find it to toggle pointer-events
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden';

      // The actual AdSense <ins> element.
      final ins = html.Element.tag('ins')
        ..classes.add('adsbygoogle')
        ..style.display = 'block'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('data-ad-client', _kAdClient)
        ..setAttribute('data-ad-slot', widget.adSlot)
        ..setAttribute('data-ad-format', widget.adFormat)
        ..setAttribute('data-full-width-responsive', 'true');

      container.append(ins);

      // Push after element is in the DOM.
      Future.delayed(const Duration(milliseconds: 200), () {
        try {
          js.context.callMethod('eval',
              ['(window.adsbygoogle = window.adsbygoogle || []).push({})']);
        } catch (_) {
          // adsbygoogle not yet loaded — auto-pushed when script initialises.
        }
      });

      return container;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin

    // SizedBox gives HtmlElementView a DEFINITE bounded height.
    // ConstrainedBox(minHeight) is NOT sufficient and causes assertion failures
    // in rendering/object.dart when inside SliverList or shrinkWrap ListView.
    return Container(
      margin: widget.margin ??
          const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      // Adding a pointer interceptor visually (empty space) is not needed if we keep-alive.
      // We wrap the ad in a container to ensure it stays isolated.
      child: SizedBox(
        height: widget.minHeight,
        width: double.infinity,
        child: HtmlElementView(viewType: _viewId),
      ),
    );
  }
}
