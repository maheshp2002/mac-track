import 'package:flutter/material.dart';

class ListCard extends StatelessWidget {
  final String image;
  final String title;
  final Widget subTitle;
  final String suffix;
  final Widget footer;

  const ListCard({
    Key? key,
    required this.image,
    required this.title,
    required this.subTitle,
    required this.suffix,
    required this.footer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      minTileHeight: 80,
      leading: Container(
        child: image.startsWith('http')
            ? Image.network(image)
            : Image.asset(image),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.start,
            ),
            const SizedBox(
              height: 5,
            ),
            subTitle
          ]),
          Text(
            suffix,
            style: theme.textTheme.headlineLarge,
          ),
        ],
      ),
      subtitle: footer,
    );
  }
}
