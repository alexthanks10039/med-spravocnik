import 'package:flutter/material.dart';

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.child,
    this.title,
    this.actions = const [],
    this.maxWidth = 1180,
  });
  final Widget child;
  final String? title;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: CustomScrollView(
      slivers: [
        if (title != null)
          SliverAppBar.large(
            title: Text(title!),
            actions: actions,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
                child: child,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
