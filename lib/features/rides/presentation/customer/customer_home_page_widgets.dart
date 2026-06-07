part of 'customer_home_page.dart';

class DraggableGrowingSheet extends StatelessWidget {
  final Widget child;

  const DraggableGrowingSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.4,
      maxChildSize: 0.65,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        );
      },
    );
  }
}
