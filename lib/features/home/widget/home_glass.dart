part of 'avpn_home_body.dart';

/// Contrast's panel at the bottom of every page (the shell keeps it): white by day, black by night, the connect
/// control on it and the "Серверы VPN" tab on its top edge.
class ContrastShellDock extends HookConsumerWidget {
  const ContrastShellDock({super.key, this.side = false, this.page = -1});

  /// the phone, without tabs: which of the three pages (0 statistics, 1 home, 2 topology) is open, marked under the
  /// control; -1 where the menu is there (a computer)
  final int page;

  /// a column at the right of the page (a short screen: the phone turned), not a panel under it
  final bool side;

  /// a screen too low for the panel under the page (the folded phone turned)
  static bool sideways(BuildContext context) => MediaQuery.sizeOf(context).height < 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final testing = useValueListenable(homePingTesting);
    final status = ref.watch(shownConnectionProvider);
    final networkKind = useListenable(_actualNetworkKind).value;
    final dock = _GraphiteDock(
      status: status,
      server: null,
      actualMobile: networkKind == NetworkKind.mobile,
      networkKnown: networkKind != NetworkKind.unknown,
      testing: testing,
      onCheck: () => pingAllServers(ref),
      large: !side && MediaQuery.sizeOf(context).height >= 900,
    );
    if (side) {
      // a column at the right: the tab at its top, the connect control in the middle
      return Theme(
        data: contrastPanelTheme(theme),
        child: Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          decoration: BoxDecoration(
            color: contrastPanelColor(dark),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
            border: dark ? Border(left: BorderSide(color: Colors.white.withValues(alpha: .08))) : null,
            boxShadow: dark
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 30, offset: const Offset(-6, 0))],
          ),
          child: Column(
            children: [
              Expanded(child: Center(child: dock)),
              // the home screen's toggles, here where there's room
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: _CheckRow(onCheck: () => pingAllServers(ref), testing: testing, showCheck: false),
              ),
            ],
          ),
        ),
      );
    }
    return Theme(
      data: contrastPanelTheme(theme),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8 + (page >= 0 ? MediaQuery.viewPaddingOf(context).bottom : 0)),
            decoration: BoxDecoration(
              color: contrastPanelColor(dark),
              borderRadius: BorderRadius.vertical(top: Radius.circular(homeLookNow == HomeLayout.dots ? 0 : 30)),
              // Dots: no edge, the control right on the page
              border: homeLookNow == HomeLayout.dots
                  ? null
                  : (dark ? Border(top: BorderSide(color: Colors.white.withValues(alpha: .08))) : null),
              boxShadow: dark || homeLookNow == HomeLayout.dots
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .07),
                        blurRadius: 30,
                        offset: const Offset(0, -6),
                      ),
                    ],
            ),
            child: page < 0
                ? dock
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      dock,
                      const Gap(8),
                      // three small squares: statistics, home, topology (swipe sideways)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: i == page
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface.withValues(alpha: .22),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Contrast's backdrop behind a page, behind the app bar too: the kind and the colours chosen in Settings →
/// Themes, laid out at random once when the app starts (the same on every page until it's closed). Inside another
/// one it draws nothing of its own.
class ContrastGlow extends ConsumerStatefulWidget {
  const ContrastGlow({super.key, required this.child, this.page = '', this.own = false, this.muted = false});

  final Widget child;

  /// a page with text right on the backdrop (the settings' sections, the profiles): the backdrop toned down under
  /// a veil of the page colour, so the text reads over the bright stripes
  final bool muted;

  /// the veil over a muted page's backdrop
  static Color veil(bool dark) => ContrastColours.active.page(dark).withValues(alpha: .78);

  /// draws its own backdrop inside another one too: a page sliding over another carries its own, so the one under
  /// it doesn't show through
  final bool own;

  /// the page it's behind (the backdrop is the same on every page)
  final String page;

  @override
  ConsumerState<ContrastGlow> createState() => _ContrastGlowState();
}

class _ContrastGlowState extends ConsumerState<ContrastGlow> {
  @override
  Widget build(BuildContext context) {
    if (!widget.own && context.findAncestorStateOfType<_ContrastGlowState>() != null) return widget.child;
    final brightness = Theme.of(context).brightness;
    final palette = ref.watch(contrastColoursProvider);
    // the light look: no picture behind, the page's colour (nothing to draw, nothing kept in memory)
    if (ref.watch(lightLookProvider)) {
      return _GlowAnchor(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(child: ColoredBox(color: palette.page(brightness == Brightness.dark))),
            widget.child,
          ],
        ),
      );
    }
    // the settings not read yet (the first frames): the defaults
    final ready = ref.watch(sharedPreferencesProvider).hasValue;
    // Bento and Dots: a backdrop of their own (a plain page, dotted paper)
    final look = ready ? ref.watch(Preferences.homeLayout) : HomeLayout.classic;
    homeLookNow = look;
    // (the settings not read yet: the colour it starts with)
    dotsAccentNow = ready
        ? ref.watch(Preferences.dotsAccent).on(dark: brightness == Brightness.dark)
        : DotsAccent.fallback.colour;
    final own = lookBackdrop(look, brightness == Brightness.dark);
    if (own != null) {
      return _GlowAnchor(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(child: RepaintBoundary(child: own)),
            widget.child,
          ],
        ),
      );
    }
    final layout = ref.watch(contrastBackdropLayoutProvider);
    final (warm, cool) = palette.backdrop(brightness);
    final area = contrastImageArea(MediaQuery.sizeOf(context));
    // the picture at the screen's sharpness, two pixels a point at most (blurrier lines aren't seen, memory is)
    final scale = math.min(MediaQuery.devicePixelRatioOf(context), PlatformUtils.isDesktop ? 1.25 : 2.0);
    ui.Image picture(int seed) => ContrastBackdropImage.of(
      kind: ready ? ref.watch(Preferences.contrastBackdrop) : ContrastBackdrop.fallback,
      warm: warm,
      cool: cool,
      dark: brightness == Brightness.dark,
      // laid out on the screen, so every page's lines up with the rest
      area: area,
      scale: scale,
      seed: seed,
      page: palette.page(brightness == Brightness.dark),
      glass: palette.glass(brightness),
    );
    final image = picture(layout.seed);
    final previous = layout.previous == layout.seed ? null : picture(layout.previous);
    return _GlowAnchor(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: ContrastImagePainter(image, scale, previous: previous)),
            ),
          ),
          if (widget.muted) Positioned.fill(child: ColoredBox(color: ContrastGlow.veil(brightness == Brightness.dark))),
          widget.child,
        ],
      ),
    );
  }
}

/// The area Contrast's backdrop and frost pictures are laid out on: the screen's; a computer's window rounded up to
/// the next 96 points, so dragging its edge doesn't draw both pictures afresh at every step (that stuttered)
Size contrastImageArea(Size screen) =>
    PlatformUtils.isDesktop ? Size((screen.width / 96).ceil() * 96.0, (screen.height / 96).ceil() * 96.0) : screen;

/// A block on Contrast's upper zone: a pane of frosted glass, what's behind it blurred.
class _ContrastBlock extends StatelessWidget {
  const _ContrastBlock({required this.child, this.expand = false});

  final Widget child;

  /// the child takes the block's height (the traffic)
  final bool expand;

  @override
  // Bento and Dots draw their own tiles and paper: no frosted pane round them
  Widget build(BuildContext context) => _bareLayout(_homeLayoutOf(context)) ? child : ContrastFrost(child: child);
}

/// Contrast's frosted glass: the backdrop behind it blurred, a light tint and a bright edge. The blur is the
/// backdrop's picture blurred once ([ContrastFrostImage]), its part under the block shown, not a live blur on every
/// frame.
class ContrastFrost extends ConsumerWidget {
  const ContrastFrost({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = const EdgeInsets.all(8),
    this.solo = false,
  });

  /// a card with nothing of its own inside (another page's): a little denser, as the home block with its tiles
  final bool solo;

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Bento and Dots: their own cards (a solid tile, an outlined box on the paper)
    final lookReady = ref.watch(sharedPreferencesProvider).hasValue;
    final card = lookCard(
      lookReady ? ref.watch(Preferences.homeLayout) : HomeLayout.classic,
      dark,
      child: child,
      padding: padding,
      radius: radius,
    );
    if (card != null) return card;
    // how see-through, as chosen in Settings → Themes
    final clarity = ref.watch(sharedPreferencesProvider).hasValue
        ? ref.watch(Preferences.contrastClarity)
        : ContrastClarity.fallback;
    // the light look: a plain pane, nothing frosted behind it
    if (ref.watch(lightLookProvider)) {
      return RepaintBoundary(
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: ContrastColours.of(context).pane(dark),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: dark ? Colors.white.withValues(alpha: .12) : Colors.black.withValues(alpha: .1)),
          ),
          child: child,
        ),
      );
    }
    return _FrostedBackdrop(
      radius: radius,
      // the block's content in a layer of its own: what moves in it (a clock, a figure) is drawn again alone, not
      // with the frosted backdrop and the blocks beside it
      child: RepaintBoundary(
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            // lighter than the chosen clarity: the tiles inside add their own pane, and the two together came out
            // nearly solid next to the other pages' single see-through cards
            color: dark
                ? ContrastColours.of(context).pane(true).withValues(alpha: clarity.night * (solo ? .75 : .6))
                : Colors.white.withValues(alpha: clarity.day * (solo ? .75 : .6)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .7)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The blurred backdrop's part under [child], clipped to its rounded shape.
class _FrostedBackdrop extends ConsumerWidget {
  const _FrostedBackdrop({required this.child, required this.radius});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final ready = ref.watch(sharedPreferencesProvider).hasValue;
    final palette = ref.watch(contrastColoursProvider);
    final clarity = ready ? ref.watch(Preferences.contrastClarity) : ContrastClarity.fallback;
    final (warm, cool) = palette.backdrop(brightness);
    final scale = math.min(MediaQuery.devicePixelRatioOf(context), 1.0);
    final kind = ready ? ref.watch(Preferences.contrastBackdrop) : ContrastBackdrop.fallback;
    final layout = ref.watch(contrastBackdropLayoutProvider);
    ui.Image picture(int seed) => ContrastFrostImage.of(
      kind: kind,
      warm: warm,
      cool: cool,
      dark: brightness == Brightness.dark,
      area: contrastImageArea(MediaQuery.sizeOf(context)),
      // thin lines blurred lightly (they still show), filled shapes harder (their bright edges ran through the text)
      blur: palette.glass(brightness) != null || kind.lines ? clarity.blur : 12,
      scale: scale,
      seed: seed,
      page: palette.page(brightness == Brightness.dark),
      glass: palette.glass(brightness),
    );
    final image = picture(layout.seed);
    // the layout before, under the new one while that fades in (the VPN on or off)
    final previous = layout.previous == layout.seed ? null : picture(layout.previous);
    // on a muted page the backdrop under the frost is toned down too
    final muted = context.findAncestorStateOfType<_ContrastGlowState>()?.widget.muted ?? false;
    final frost = _FrostPart(
      image: image,
      previous: previous,
      scale: scale,
      radius: radius,
      scroll: Scrollable.maybeOf(context)?.position,
      child: child,
    );
    if (!muted) return frost;
    return _FrostPart(
      image: image,
      previous: previous,
      scale: scale,
      radius: radius,
      scroll: Scrollable.maybeOf(context)?.position,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ContrastGlow.veil(brightness == Brightness.dark),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

/// Marks a backdrop's box: frost inside it takes its part of the picture by its place in this box, so a page
/// sliding with its backdrop keeps its frost right without being repainted (it jumped when the tabs changed).
class _GlowAnchor extends SingleChildRenderObjectWidget {
  const _GlowAnchor({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGlowAnchor();
}

class _RenderGlowAnchor extends RenderProxyBox {}

class _FrostPart extends SingleChildRenderObjectWidget {
  const _FrostPart({
    required this.image,
    required this.scale,
    required this.radius,
    this.previous,
    this.scroll,
    super.child,
  });

  final ui.Image image;

  /// the layout before, under the new one while that fades in
  final ui.Image? previous;

  /// the picture's pixels per point
  final double scale;
  final double radius;

  /// the list it's in: it moves over the backdrop as that scrolls
  final Listenable? scroll;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFrostPart(image, radius, scroll)
    ..scale = scale
    ..previous = previous;

  @override
  void updateRenderObject(BuildContext context, _RenderFrostPart renderObject) => renderObject
    ..image = image
    ..previous = previous
    ..scale = scale
    ..radius = radius
    ..scroll = scroll;
}

class _RenderFrostPart extends RenderProxyBox {
  _RenderFrostPart(this._image, this._radius, this._scroll);

  double _scale = 1;
  set scale(double v) {
    if (v == _scale) return;
    _scale = v;
    markNeedsPaint();
  }

  Listenable? _scroll;
  set scroll(Listenable? v) {
    if (identical(v, _scroll)) return;
    if (attached) _scroll?.removeListener(markNeedsPaint);
    _scroll = v;
    if (attached) _scroll?.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scroll?.addListener(markNeedsPaint);
    if (_previous != null) ContrastBackdropLayout.fade.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scroll?.removeListener(markNeedsPaint);
    ContrastBackdropLayout.fade.removeListener(markNeedsPaint);
    super.detach();
  }

  /// the layout before, faded out as the new one fades in: repainted with the fade only while there is one
  ui.Image? _previous;
  set previous(ui.Image? v) {
    if (identical(v, _previous)) return;
    if (attached) {
      ContrastBackdropLayout.fade.removeListener(markNeedsPaint);
      if (v != null) ContrastBackdropLayout.fade.addListener(markNeedsPaint);
    }
    _previous = v;
    markNeedsPaint();
  }

  ui.Image _image;
  set image(ui.Image v) {
    if (identical(v, _image)) return;
    _image = v;
    markNeedsPaint();
  }

  double _radius;
  set radius(double v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // where the block is on its backdrop (laid out from the backdrop's corner, as the picture is): found from the
    // nearest one round it, which moves with the page; the screen when there's none
    RenderObject? up = parent;
    while (up != null && up is! _RenderGlowAnchor) {
      up = up.parent;
    }
    final at = localToGlobal(Offset.zero, ancestor: up);
    final k = _scale;
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(offset & size, Radius.circular(_radius)));
    // whole pixels of the picture: a part taken between them was resampled anew each frame and the lines shimmered
    final part = Rect.fromLTWH(
      (at.dx * k).roundToDouble(),
      (at.dy * k).roundToDouble(),
      size.width * k,
      size.height * k,
    );
    final fade = ContrastBackdropLayout.fade.value;
    final old = _previous;
    if (old != null && fade < 1) {
      canvas.drawImageRect(old, part, offset & size, Paint()..filterQuality = FilterQuality.low);
    }
    canvas.drawImageRect(
      _image,
      part,
      offset & size,
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(0, 0, 0, old != null && fade < 1 ? fade : 1),
    );
    canvas.restore();
    super.paint(context, offset);
  }
}

/// Contrast's panel: pure white by day, pure black by night.
Color contrastPanelColor(bool dark) => switch (homeLookNow) {
  HomeLayout.bento => dark ? const Color(0xFF1A1A1E) : Colors.white,
  HomeLayout.dots => _Dots.paper(dark),
  _ => dark ? Colors.black : Colors.white,
};

/// The look Contrast's panel is drawn in: by night light text on black, the accent lifted to read on it; by day
/// the page's own look on white.
ThemeData contrastPanelTheme(ThemeData theme) {
  // the same for the same input (see [lookTheme]): the panel rebuilt with a new theme at every tick of its clock
  final kept = _panelThemes[theme];
  if (kept != null) return kept;
  if (_panelThemes.length > 8) _panelThemes.clear();
  return _panelThemes[theme] = _contrastPanelTheme(theme);
}

final _panelThemes = <ThemeData, ThemeData>{};

ThemeData _contrastPanelTheme(ThemeData theme) {
  if (theme.brightness == Brightness.light) {
    return theme.copyWith(colorScheme: theme.colorScheme.copyWith(surface: Colors.white));
  }
  const ink = Color(0xFFF3F1EC);
  final hsl = HSLColor.fromColor(theme.colorScheme.primary);
  final primary = hsl.lightness < .55 ? hsl.withLightness(.62).toColor() : theme.colorScheme.primary;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(bodyColor: ink, displayColor: ink),
    iconTheme: const IconThemeData(color: ink),
    colorScheme: theme.colorScheme.copyWith(
      primary: primary,
      onPrimary: const Color(0xFF111111),
      surface: Colors.black,
      onSurface: ink,
      onSurfaceVariant: const Color(0xFF8F8C86),
      surfaceContainerLow: const Color(0xFF111113),
      surfaceContainer: const Color(0xFF18181B),
      surfaceContainerHigh: const Color(0xFF1F1F22),
      surfaceContainerHighest: const Color(0xFF27272B),
      outlineVariant: const Color(0xFF34343A),
      outline: const Color(0xFF55555B),
    ),
  );
}

/// Contrast's popups: a see-through frosted card in the middle of the screen, a fifth smaller than the screen's
/// free room, growing from just above the panel.
Future<void> showGlassPopup(BuildContext context, Widget child) async {
  // the page under it held as a picture while it opens and closes (see [FreezeFrame])
  final frozen = await FreezeFrame.freeze();
  if (!context.mounted) {
    if (frozen) FreezeFrame.thawSoon();
    return;
  }
  // the page's themes (Bento's and Dots' faces and colours) carried into the popup
  final themes = InheritedTheme.capture(from: context, to: Navigator.of(context, rootNavigator: true).context);
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black26,
      transitionDuration: lightDuration(const Duration(milliseconds: 300)),
      pageBuilder: (_, _, _) => themes.wrap(_GlassPopup(child: child)),
      transitionBuilder: (context, animation, _, child) =>
          HomePopupTransition(animation: animation, alignment: const Alignment(0, .9), child: child),
    );
  } finally {
    if (frozen) FreezeFrame.thawSoon();
  }
}

class _GlassPopup extends ConsumerWidget {
  const _GlassPopup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screen = MediaQuery.sizeOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // as wide as the route's card (a traffic tile's): the screen less 16 at each side
          maxWidth: math.min(screen.width - 32, 440),
          maxHeight: (screen.height - 120) * .8,
        ),
        // solid: the see-through glass still stuttered as it opened
        child: Material(
          color: lookPopupColour(homeLookNow, dark) ?? (dark ? const Color(0xFF1C1C1F) : const Color(0xFFF7F5F1)),
          clipBehavior: Clip.antiAlias,
          shape:
              lookPopupShape(homeLookNow, dark) ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
                side: BorderSide(
                  color: dark ? Colors.white.withValues(alpha: .1) : Colors.black.withValues(alpha: .06),
                ),
              ),
          child: child,
        ),
      ),
    );
  }
}

/// A window's glass by the clarity chosen in Settings → Themes: what's behind it blurred, [builder] given the tint.
class ContrastClear extends ConsumerWidget {
  const ContrastClear({super.key, required this.builder, this.radius = 26});

  final Widget Function(Color tint) builder;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // solid: the see-through glass still stuttered as the card opened
    return builder(dark ? const Color(0xFF1C1C1F) : const Color(0xFFF7F5F1));
  }
}

/// A round frosted plate under an icon button (Contrast's "+" and cog).
class ContrastPlate extends ConsumerWidget {
  const ContrastPlate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final clarity = ref.watch(Preferences.contrastClarity);
    // Bento and Dots: their own plates
    final own = lookPlate(ref.watch(Preferences.homeLayout), context, child);
    if (own != null) return own;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: _FrostedBackdrop(
        radius: 100,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark
                ? ContrastColours.of(context).pane(true).withValues(alpha: clarity.night)
                : Colors.white.withValues(alpha: clarity.day),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .7)),
          ),
          child: child,
        ),
      ),
    );
  }
}
