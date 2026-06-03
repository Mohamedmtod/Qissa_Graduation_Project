import 'package:file_picker/file_picker.dart';

import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/media_file_picker/media_file_picker_types.dart';

Future<PickedMediaFile?> pickMediaImageFile() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: true,
    type: FileType.image,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }

  final file = result.files.first;
  final bytes = file.bytes;
  final name = file.name.trim();
  if (bytes == null || bytes.isEmpty || name.isEmpty) {
    return null;
  }

  return PickedMediaFile(
    name: name,
    bytes: bytes,
    contentType: file.xFile.mimeType,
    extension: file.extension,
  );
}
