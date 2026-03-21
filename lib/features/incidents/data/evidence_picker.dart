import 'selected_evidence_image.dart';
import 'evidence_picker_stub.dart'
    if (dart.library.html) 'evidence_picker_web.dart'
    as picker;

Future<SelectedEvidenceImage?> pickEvidenceImage() =>
    picker.pickEvidenceImage();
