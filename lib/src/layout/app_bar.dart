import 'package:flutter/material.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      excludeHeaderSemantics: true,
      title: Image.asset(
        'assets/images/logo_main.png',
        fit: BoxFit.cover,
        height: 55,
        excludeFromSemantics: true,
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Image.asset(
            "assets/images/hashtag-local-af.png", 
            height: 18,
            excludeFromSemantics: true,
          ),
        )
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}