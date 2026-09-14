import 'package:flutter/material.dart';

class ChatFileCard extends StatelessWidget {
  const ChatFileCard({
    super.key,
    required this.fileName,
    required this.size,
    this.onTap,
  });
  final String fileName;
  final int size;
  final VoidCallback? onTap;
  static String formatSize(int size) => size < 1024
      ? '$size B'
      : size < 1024 * 1024
      ? '${(size / 1024).toStringAsFixed(1)} KB'
      : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  @override
  Widget build(BuildContext context) => Semantics(
    label: '文件，$fileName，${formatSize(size)}',
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF24211D),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              color: Color(0xFFC6B79F),
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatSize(size),
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
