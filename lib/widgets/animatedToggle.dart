import 'package:flutter/material.dart';

class AnimatedToggle extends StatefulWidget {
  final List<String> values;
  final ValueChanged<int> onToggleCallback;
  final Color backgroundColor;
  final Color buttonColor;
  final int initialIndex;
  final Color textColor;

  const AnimatedToggle({
    required this.values,
    required this.initialIndex,
    required this.onToggleCallback,
    this.backgroundColor = const Color(0xFFe7e7e8),
    this.buttonColor = const Color(0xFFFFFFFF),
    this.textColor = const Color(0xFF000000),
    Key? key,
  }) : super(key: key);

  @override
  _AnimatedToggleState createState() => _AnimatedToggleState();
}

class _AnimatedToggleState extends State<AnimatedToggle> {
  late bool initialPosition;
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    initialPosition = widget.initialIndex == 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Container(
          width: width,
          height: height,
          child: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    initialPosition = !initialPosition;
                    index = initialPosition ? 0 : 1;
                  });
                  widget.onToggleCallback(index);
                },
                child: Container(
                  width: width,
                  height: height,
                  margin: const EdgeInsets.all(1.0),
                  decoration: ShapeDecoration(
                    color: widget.backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(height * 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      widget.values.length,
                          (i) =>
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(i == 0 ? Icons.sunny : Icons.nightlight_outlined),
                                const SizedBox(width: 5),
                                Text(
                                  widget.values[i],
                                  style: TextStyle(
                                    fontFamily: 'Rubik',
                                    fontSize: height * 0.4,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xAA000000),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.decelerate,
                alignment: initialPosition ? Alignment.centerLeft : Alignment.centerRight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: width * 0.5,
                  height: height,
                  margin: const EdgeInsets.all(3.0),
                  decoration: ShapeDecoration(
                    color: widget.buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(height * 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(initialPosition ? Icons.sunny : Icons.nightlight_outlined),
                      const SizedBox(width: 5),
                      Text(
                        initialPosition ? widget.values[0] : widget.values[1],
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: height * 0.4,
                          color: widget.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}