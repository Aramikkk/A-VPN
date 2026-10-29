part of 'avpn_home_body.dart';

/// The home screen's look in use (Settings → Themes → Home), for widgets with no provider reference of their own (the
/// super light mode keeps it too: its own lighter form of the look).
HomeLayout _homeLayoutOf(BuildContext context) {
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    return container.read(Preferences.homeLayout);
  } catch (_) {
    return HomeLayout.classic;
  }
}

/// The Dots style's one colour as chosen (by day or by night), set where the look is: the shell and the backdrop.
Color dotsAccentNow = DotsAccent.fallback.colour;

/// A server's flag as the look draws it: pixels in Dots (about [width] wide), the emoji (of [emoji] size) in the others.
Widget flagGlyph(String? flag, {required double emoji, required double width}) => homeLookNow == HomeLayout.dots
    ? flagMark(flag, width: width)
    : Text(
        flag ?? '🌐',
        style: TextStyle(fontSize: emoji, fontFamilyFallback: const ['Emoji']),
      );

/// The home screen's look as the backdrop last drew it: for the panel's colour and the connect control, which have no
/// provider reference of their own.
HomeLayout homeLookNow = HomeLayout.classic;

/// Bento's page under the tiles: plain, no stripes.
Color _bentoPage(bool dark) => dark ? const Color(0xFF0E0E10) : const Color(0xFFF2F2F5);

/// The backdrop of a look that has its own (Bento's plain page, Dots' dotted paper), or null for the others.
Widget? lookBackdrop(HomeLayout look, bool dark) => switch (look) {
  HomeLayout.bento => ColoredBox(color: _bentoPage(dark)),
  HomeLayout.dots => CustomPaint(
    painter: _DotGridPainter(paper: _Dots.paper(dark), dot: _Dots.grid(dark)),
  ),
  _ => null,
};

/// A card of another page in a look that has its own (Bento's solid tile, Dots' outlined box on the paper), or null.
Widget? lookCard(
  HomeLayout look,
  bool dark, {
  required Widget child,
  required EdgeInsets padding,
  required double radius,
}) => switch (look) {
  HomeLayout.bento => Container(
    padding: padding,
    decoration: BoxDecoration(color: _Bento.tile(dark), borderRadius: BorderRadius.circular(bentoRadius)),
    child: child,
  ),
  HomeLayout.dots => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _Dots.paper(dark),
      borderRadius: BorderRadius.circular(dotsRadius),
      border: Border.all(color: _Dots.ink(dark).withValues(alpha: .28)),
    ),
    child: child,
  ),
  _ => null,
};

/// The corner every pane of a look has: Bento's round tiles, Dots' nearly square boxes.
const bentoRadius = 26.0;
const dotsRadius = 6.0;

/// the corner of a pane in [look] (null: the look's own as the caller has it)
double? lookRadius(HomeLayout look) => switch (look) {
  HomeLayout.bento => bentoRadius,
  HomeLayout.dots => dotsRadius,
  _ => null,
};

/// the looks whose blocks draw their own tiles (no frosted pane round them)
bool _bareLayout(HomeLayout layout) => layout == HomeLayout.bento || layout == HomeLayout.dots;

/// A pill over the sites (the delay check, the multi-server switch) in a look that has its own: Bento's solid chip,
/// the accent when on; Dots' square-cornered box in small capitals, filled with the ink when on. Null for the others.
({BoxDecoration box, Color ink, TextStyle? text})? lookPill(HomeLayout look, BuildContext context, {required bool on}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  switch (look) {
    case HomeLayout.bento:
      final ink = on ? _onAccent(theme.araAccent) : theme.colorScheme.onSurface;
      return (
        box: BoxDecoration(color: on ? theme.araAccent : _Bento.inner(dark), borderRadius: BorderRadius.circular(15)),
        ink: ink,
        text: _Bento.label(ink).copyWith(fontSize: 12, fontWeight: FontWeight.w800),
      );
    case HomeLayout.dots:
      final ink = on ? _Dots.paper(dark) : _Dots.ink(dark);
      return (
        box: BoxDecoration(
          color: on ? _Dots.ink(dark) : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _Dots.ink(dark).withValues(alpha: .35)),
        ),
        ink: ink,
        text: _Dots.mono(11, ink, weight: FontWeight.w700),
      );
    default:
      return null;
  }
}

/// A round button over the page (the modes, the leaf, the cog) in a look that has its own: Bento's solid tile,
/// Dots' outlined circle on the paper. Null for the others.
Widget? lookPlate(HomeLayout look, BuildContext context, Widget child) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (look) {
    HomeLayout.bento => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(color: _Bento.tile(dark), borderRadius: BorderRadius.circular(15)),
        child: IconTheme.merge(
          data: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
          child: child,
        ),
      ),
    ),
    HomeLayout.dots => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _Dots.paper(dark),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _Dots.ink(dark).withValues(alpha: .35)),
        ),
        child: child,
      ),
    ),
    _ => null,
  };
}

/// The ping's marks in Dots: the ink for what is well, the style's colour from [slowAt] ms on. The pages' theme keeps the
/// palette's accent (a neon one chosen once); Dots' one colour is the chosen one, so these carry it.
class _DotsLook extends AraLook {
  const _DotsLook({
    required this.ink,
    required this.accent,
    required super.fastPing,
    super.gradient,
    super.onGradient,
    super.border,
    super.data,
    super.dark,
    super.graphDown,
    super.graphUp,
    super.pingOn,
  }) : super(fill: accent);

  final Color ink;
  final Color accent;

  static const slowAt = 300;

  @override
  List<Color> get pingColors => [ink, ink, ink, accent];

  @override
  Color pingColor(int ms, Color muted) => ms >= slowAt ? accent : ink;
}

/// [theme] (a page's) with the Dots look's colours: the chosen accent where the page draws the theme's accent (the VPN
/// routes, the loss, the lit things), the ping's marks in the ink and the accent. Kept for the same input.
ThemeData dotsPageColours(ThemeData theme, DotsAccent accent) {
  final key = (theme, accent);
  final kept = _dotsPageThemes[key];
  if (kept != null) return kept;
  if (_dotsPageThemes.length > 8) _dotsPageThemes.clear();
  final dark = theme.brightness == Brightness.dark;
  final look = theme.extension<AraLook>();
  final result = theme.copyWith(
    extensions: [
      for (final e in theme.extensions.values)
        if (e is! AraLook) e,
      _DotsLook(
        ink: _Dots.ink(dark),
        accent: accent.on(dark: dark),
        fastPing: _Dots.ink(dark),
        gradient: look?.gradient,
        onGradient: look?.onGradient ?? Colors.white,
        border: look?.border,
        data: look?.data,
        dark: dark,
        graphDown: look?.graphDown,
        graphUp: look?.graphUp,
        pingOn: look?.pingOn,
      ),
    ],
  );
  return _dotsPageThemes[key] = result;
}

final _dotsPageThemes = <(ThemeData, DotsAccent), ThemeData>{};

/// The whole screen in a look that has its own (the pages, the menu, the panel): Dots in its monospaced face with the
/// ink for the accent of the text and a square-cornered outlined tab; Bento its heavy round face for the titles and a
/// solid tab in the accent. The others as they are.
ThemeData lookTheme(ThemeData theme, HomeLayout look, [DotsAccent accent = DotsAccent.fallback]) {
  // the same theme for the same input: a new one at every build of the shell (a tab switched) told the whole app its
  // theme had changed and rebuilt it all, a stall of a tenth of a second at each switch
  final key = (theme, look, look == HomeLayout.dots ? accent : DotsAccent.fallback);
  final kept = _lookThemes[key];
  if (kept != null) return kept;
  if (_lookThemes.length > 8) _lookThemes.clear();
  return _lookThemes[key] = _lookTheme(theme, look, accent);
}

final _lookThemes = <(ThemeData, HomeLayout, DotsAccent), ThemeData>{};

ThemeData _lookTheme(ThemeData theme, HomeLayout look, DotsAccent accent) {
  final dark = theme.brightness == Brightness.dark;
  switch (look) {
    case HomeLayout.dots:
      final ink = _Dots.ink(dark);
      final soft = _Dots.soft(dark);
      // the accent is the ink: no palette fill (by day a light palette fills the lit things in its colour)
      final araLook = theme.extension<AraLook>();
      return theme.copyWith(
        extensions: [
          for (final e in theme.extensions.values)
            if (e is! AraLook) e,
          if (araLook != null)
            AraLook(
              gradient: araLook.gradient,
              onGradient: araLook.onGradient,
              fastPing: araLook.fastPing,
              border: araLook.border,
              data: araLook.data,
              dark: araLook.dark,
              graphDown: araLook.graphDown,
              graphUp: araLook.graphUp,
              pingOn: araLook.pingOn,
            ),
        ],
        textTheme: theme.textTheme.apply(fontFamily: 'JetBrains Mono'),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)?.copyWith(
            fontFamily: 'JetBrains Mono',
          ),
        ),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'JetBrains Mono'),
        // (the chosen colour rides in the scheme's tertiary: a change of it is a change of the theme, so the screens
        // drawing it are built again)
        colorScheme: theme.colorScheme.copyWith(
          primary: ink,
          onPrimary: _Dots.paper(dark),
          tertiary: accent.on(dark: dark),
        ),
        // the settings' signs and every other icon in the ink
        iconTheme: theme.iconTheme.copyWith(color: ink),
        listTileTheme: theme.listTileTheme.copyWith(iconColor: ink),
        chipTheme: theme.chipTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: ink.withValues(alpha: .6)),
          ),
          side: BorderSide(color: ink.withValues(alpha: .6)),
          backgroundColor: Colors.transparent,
          selectedColor: ink,
          checkmarkColor: _Dots.paper(dark),
          labelStyle: _Dots.mono(12, ink, weight: FontWeight.w700, spacing: .6),
          secondaryLabelStyle: _Dots.mono(12, _Dots.paper(dark), weight: FontWeight.w700, spacing: .6),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            side: WidgetStatePropertyAll(BorderSide(color: ink.withValues(alpha: .6))),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? ink : Colors.transparent,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? _Dots.paper(dark) : ink,
            ),
          ),
        ),
        sliderTheme: theme.sliderTheme.copyWith(
          activeTrackColor: ink,
          thumbColor: ink,
          inactiveTrackColor: soft.withValues(alpha: .4),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? _Dots.paper(dark) : soft,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? ink : Colors.transparent,
          ),
          trackOutlineColor: WidgetStatePropertyAll(ink.withValues(alpha: .6)),
        ),
        bottomSheetTheme: theme.bottomSheetTheme.copyWith(
          backgroundColor: _Dots.paper(dark),
          modalBackgroundColor: _Dots.paper(dark),
          shape: lookPopupShape(HomeLayout.dots, dark),
        ),
        dialogTheme: theme.dialogTheme.copyWith(
          backgroundColor: _Dots.paper(dark),
          shape: lookPopupShape(HomeLayout.dots, dark),
        ),
        navigationBarTheme: theme.navigationBarTheme.copyWith(
          indicatorColor: ink.withValues(alpha: .08),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: ink.withValues(alpha: .7)),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(color: states.contains(WidgetState.selected) ? ink : soft),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => _Dots.mono(
              11,
              states.contains(WidgetState.selected) ? ink : soft,
              weight: FontWeight.w700,
              spacing: .6,
            ),
          ),
        ),
      );
    case HomeLayout.bento:
      final t = theme.textTheme;
      TextStyle? heavy(TextStyle? style) => style?.copyWith(fontFamily: 'Unbounded', letterSpacing: -.2);
      return theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: heavy(theme.appBarTheme.titleTextStyle ?? t.titleLarge),
        ),
        textTheme: t.copyWith(
          displayLarge: heavy(t.displayLarge),
          displayMedium: heavy(t.displayMedium),
          displaySmall: heavy(t.displaySmall),
          headlineLarge: heavy(t.headlineLarge),
          headlineMedium: heavy(t.headlineMedium),
          headlineSmall: heavy(t.headlineSmall),
          titleLarge: heavy(t.titleLarge),
        ),
        chipTheme: theme.chipTheme.copyWith(
          shape: const StadiumBorder(),
          side: BorderSide.none,
          backgroundColor: _Bento.tile(dark),
          selectedColor: theme.araAccent,
          checkmarkColor: _onAccent(theme.araAccent),
          secondaryLabelStyle: TextStyle(color: _onAccent(theme.araAccent), fontWeight: FontWeight.w800),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            side: const WidgetStatePropertyAll(BorderSide.none),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? theme.araAccent : _Bento.tile(dark),
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.selected) ? _onAccent(theme.araAccent) : theme.colorScheme.onSurface,
            ),
          ),
        ),
        bottomSheetTheme: theme.bottomSheetTheme.copyWith(
          backgroundColor: _Bento.tile(dark),
          modalBackgroundColor: _Bento.tile(dark),
          shape: lookPopupShape(HomeLayout.bento, dark),
        ),
        dialogTheme: theme.dialogTheme.copyWith(
          backgroundColor: _Bento.tile(dark),
          shape: lookPopupShape(HomeLayout.bento, dark),
        ),
        navigationBarTheme: theme.navigationBarTheme.copyWith(
          indicatorColor: theme.araAccent,
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? _onAccent(theme.araAccent)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    default:
      return theme;
  }
}

/// A popup's card in a look that has its own: Bento's solid tile, Dots' paper with an inked edge. Null for the others.
Color? lookPopupColour(HomeLayout look, bool dark) => switch (look) {
  HomeLayout.bento => _Bento.tile(dark),
  HomeLayout.dots => _Dots.paper(dark),
  _ => null,
};

ShapeBorder? lookPopupShape(HomeLayout look, bool dark) => switch (look) {
  HomeLayout.bento => RoundedRectangleBorder(borderRadius: BorderRadius.circular(bentoRadius)),
  HomeLayout.dots => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(dotsRadius),
    side: BorderSide(color: _Dots.ink(dark).withValues(alpha: .7)),
  ),
  _ => null,
};

/// A mode's square in the modes' popup in a look that has its own: Bento's solid tile, the accent when on; Dots' inked
/// box, filled with the ink when on. Null for the others.
({BoxDecoration box, Color ink})? lookSquare(HomeLayout look, BuildContext context, {required bool on}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return switch (look) {
    HomeLayout.bento => (
      box: BoxDecoration(color: on ? theme.araAccent : _Bento.inner(dark), borderRadius: BorderRadius.circular(24)),
      ink: on ? _onAccent(theme.araAccent) : theme.colorScheme.onSurface,
    ),
    HomeLayout.dots => (
      box: BoxDecoration(
        color: on ? _Dots.ink(dark) : null,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _Dots.ink(dark).withValues(alpha: .7)),
      ),
      ink: on ? _Dots.paper(dark) : _Dots.ink(dark),
    ),
    _ => null,
  };
}

/// The menu under the panel in a look that has its own. Bento: a row on the panel, the page in use a pill in the accent
/// with its sign and name, the others their sign over a small name. Dots: small capitals, the page in use its sign on
/// an inked square.
class LookNavBar extends StatelessWidget {
  const LookNavBar({
    super.key,
    required this.look,
    required this.destinations,
    required this.selected,
    required this.onSelect,
  });

  final HomeLayout look;
  final List<NavigationDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bento = look == HomeLayout.bento;
    final soft = bento ? theme.colorScheme.onSurfaceVariant : _Dots.soft(dark);
    Widget item(int i) {
      final d = destinations[i];
      final on = i == selected;
      final ink = bento ? (on ? _onAccent(theme.araAccent) : soft) : (on ? _Dots.paper(dark) : _Dots.ink(dark));
      final sign = IconTheme(
        data: IconThemeData(color: ink, size: 22),
        child: on ? (d.selectedIcon ?? d.icon) : d.icon,
      );
      final label = bento
          ? _Bento.label(on ? _onAccent(theme.araAccent) : soft).copyWith(fontSize: 12, fontWeight: FontWeight.w800)
          : _Dots.mono(10, on ? _Dots.ink(dark) : soft, weight: FontWeight.w700, spacing: 1.2);
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(i),
          child: Center(
            child: bento
                ? AnimatedContainer(
                    duration: lightDuration(const Duration(milliseconds: 220)),
                    padding: EdgeInsets.symmetric(horizontal: on ? 14 : 6, vertical: 9),
                    decoration: BoxDecoration(
                      color: on ? theme.araAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: on
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              sign,
                              const Gap(6),
                              Text(d.label, style: label),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              sign,
                              const Gap(2),
                              Text(d.label, style: label.copyWith(fontSize: 10)),
                            ],
                          ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? _Dots.ink(dark) : null,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: sign,
                      ),
                      const Gap(4),
                      Text(d.label.toUpperCase(), style: label),
                    ],
                  ),
          ),
        ),
      );
    }

    return Container(
      height: 64,
      // of a piece with the panel over it: no line between them
      decoration: BoxDecoration(color: contrastPanelColor(dark)),
      child: SafeArea(top: false, child: Row(children: [for (var i = 0; i < destinations.length; i++) item(i)])),
    );
  }
}
