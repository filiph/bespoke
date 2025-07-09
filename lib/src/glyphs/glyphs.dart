import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter95/flutter95.dart';

class Glyphs extends StatelessWidget {
  const Glyphs({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Glyph('½'),
          _Glyph('²'),
          _Glyph('∞'),
          _Glyph('π'),
          _Glyph('°'),
          _Glyph('™'),
          _Glyph('↑'),
          _Glyph('↓'),
          _Glyph('←'),
          _Glyph('→'),
          _Glyph('✔️'),
          _Glyph(' '),
          _Glyph(r'¯\_(ツ)_/¯'),
          _Glyph(r'DIČ', 'CZ04498216'),
        ],
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  final String glyph;

  final String clipboardValue;

  _Glyph(this.glyph, [String? clipboardValue])
      : clipboardValue = clipboardValue ?? glyph,
        super(key: ValueKey(glyph));

  @override
  Widget build(BuildContext context) {
    return Button95(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Text(glyph),
      onTap: () {
        Clipboard.setData(ClipboardData(text: clipboardValue));
      },
    );
  }
}
