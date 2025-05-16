import 'package:flutter/material.dart';

class CollapsableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;

  const CollapsableText({
    super.key,
    required this.text,
    required this.maxLines,
    required this.style,
  });

  @override
  State<CollapsableText> createState() => _CollapsableTextState();
}

class _CollapsableTextState extends State<CollapsableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final TextPainter textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);
        final bool doesExceedMaxLines = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: _isExpanded ? 10000 : widget.maxLines,
              overflow: TextOverflow.ellipsis, // Optional: Add a fade effect
            ),
            if (doesExceedMaxLines)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }, 
                  child: Text(
                    _isExpanded ? "Show Less" : "Show More",
                  )),
              )
          ],
        );});
  }
}