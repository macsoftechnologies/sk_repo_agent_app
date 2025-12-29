import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaPickerSection extends StatefulWidget {
  final Function(List<XFile> mediaFiles)? onMediaSelected;

  const MediaPickerSection({Key? key, this.onMediaSelected}) : super(key: key);

  @override
  State<MediaPickerSection> createState() => _MediaPickerSectionState();
}

class _MediaPickerSectionState extends State<MediaPickerSection> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _mediaFiles = [];

  Future<void> _showPickOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Pick Image"),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  setState(() => _mediaFiles.add(image));
                  widget.onMediaSelected?.call(_mediaFiles);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text("Pick Video"),
              onTap: () async {
                Navigator.pop(context);
                final XFile? video = await _picker.pickVideo(
                  source: ImageSource.gallery,
                );
                if (video != null) {
                  setState(() => _mediaFiles.add(video));
                  widget.onMediaSelected?.call(_mediaFiles);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
      return Icons.videocam_outlined;
    } else {
      return Icons.image_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Text(
          //   'Select images or videos',
          //   style: TextStyle(
          //     fontSize: 12,
          //     color: Colors.blue,
          //     fontWeight: FontWeight.w500,
          //   ),
          // ),
          // const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var file in _mediaFiles)
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _getFileIcon(file.path) == Icons.image_outlined
                          ? Image.file(
                              File(file.path),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              color: Colors.black12,
                              child: const Icon(
                                Icons.videocam_outlined,
                                size: 36,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      file.name,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              GestureDetector(
                onTap: _showPickOptions,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 32,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
