import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/reservation.dart';

enum QrWorkflowStep {
  scan,
  validate,
  tagBags,
  capturePhotos,
  storeInWarehouse,
  generatePickupPin,
  customerPickupOrDelivery,
  complete,
}

extension QrWorkflowStepX on QrWorkflowStep {
  String get label {
    switch (this) {
      case QrWorkflowStep.scan:
        return 'Scan QR';
      case QrWorkflowStep.validate:
        return 'Validate reservation';
      case QrWorkflowStep.tagBags:
        return 'Tag luggage';
      case QrWorkflowStep.capturePhotos:
        return 'Capture photos';
      case QrWorkflowStep.storeInWarehouse:
        return 'Store';
      case QrWorkflowStep.generatePickupPin:
        return 'Generate PIN';
      case QrWorkflowStep.customerPickupOrDelivery:
        return 'Delivery';
      case QrWorkflowStep.complete:
        return 'Completed';
    }
  }

  String labelWithLocale(dynamic l10n) {
    switch (this) {
      case QrWorkflowStep.scan:
        return l10n.t('qr_workflow_scan');
      case QrWorkflowStep.validate:
        return l10n.t('qr_workflow_validate');
      case QrWorkflowStep.tagBags:
        return l10n.t('qr_workflow_tag_bags');
      case QrWorkflowStep.capturePhotos:
        return l10n.t('qr_workflow_capture_photos');
      case QrWorkflowStep.storeInWarehouse:
        return l10n.t('qr_workflow_store');
      case QrWorkflowStep.generatePickupPin:
        return l10n.t('qr_workflow_generate_pin');
      case QrWorkflowStep.customerPickupOrDelivery:
        return l10n.t('qr_workflow_delivery');
      case QrWorkflowStep.complete:
        return l10n.t('qr_workflow_complete');
    }
  }

  QrWorkflowStep? get next {
    switch (this) {
      case QrWorkflowStep.scan:
        return QrWorkflowStep.validate;
      case QrWorkflowStep.validate:
        return QrWorkflowStep.tagBags;
      case QrWorkflowStep.tagBags:
        return QrWorkflowStep.capturePhotos;
      case QrWorkflowStep.capturePhotos:
        return QrWorkflowStep.storeInWarehouse;
      case QrWorkflowStep.storeInWarehouse:
        return QrWorkflowStep.generatePickupPin;
      case QrWorkflowStep.generatePickupPin:
        return QrWorkflowStep.customerPickupOrDelivery;
      case QrWorkflowStep.customerPickupOrDelivery:
        return QrWorkflowStep.complete;
      case QrWorkflowStep.complete:
        return null;
    }
  }

  bool canSkip(ReservationStatus status) {
    switch (this) {
      case QrWorkflowStep.scan:
        return false;
      case QrWorkflowStep.validate:
        return false;
      case QrWorkflowStep.tagBags:
        return status == ReservationStatus.confirmed ||
            status == ReservationStatus.checkinPending;
      case QrWorkflowStep.capturePhotos:
        return false;
      case QrWorkflowStep.storeInWarehouse:
        return false;
      case QrWorkflowStep.generatePickupPin:
        return false;
      case QrWorkflowStep.customerPickupOrDelivery:
        return status == ReservationStatus.readyForPickup ||
            status == ReservationStatus.outForDelivery;
      case QrWorkflowStep.complete:
        return false;
    }
  }
}

class QrWorkflowState {
  final QrWorkflowStep currentStep;
  final String? reservationId;
  final String? reservationCode;
  final ReservationStatus? status;
  final bool bagTagGenerated;
  final bool photosCaptured;
  final int photoCount;
  final String? bagTagId;
  final String? pickupPin;
  final bool warehouseStored;
  final bool pickupReady;
  final bool deliveryCompleted;
  final List<String> validationErrors;

  const QrWorkflowState({
    this.currentStep = QrWorkflowStep.scan,
    this.reservationId,
    this.reservationCode,
    this.status,
    this.bagTagGenerated = false,
    this.photosCaptured = false,
    this.photoCount = 0,
    this.bagTagId,
    this.pickupPin,
    this.warehouseStored = false,
    this.pickupReady = false,
    this.deliveryCompleted = false,
    this.validationErrors = const [],
  });

  bool get canProceedToNextStep {
    if (validationErrors.isNotEmpty) return false;

    switch (currentStep) {
      case QrWorkflowStep.scan:
        return reservationCode != null;
      case QrWorkflowStep.validate:
        return status != null &&
            (status == ReservationStatus.confirmed ||
                status == ReservationStatus.checkinPending);
      case QrWorkflowStep.tagBags:
        return bagTagGenerated && bagTagId != null;
      case QrWorkflowStep.capturePhotos:
        return photosCaptured && photoCount > 0;
      case QrWorkflowStep.storeInWarehouse:
        return warehouseStored;
      case QrWorkflowStep.generatePickupPin:
        return pickupReady && pickupPin != null;
      case QrWorkflowStep.customerPickupOrDelivery:
        return deliveryCompleted;
      case QrWorkflowStep.complete:
        return true;
    }
  }

  QrWorkflowStep? get nextAvailableStep {
    if (!canProceedToNextStep) return null;
    return currentStep.next;
  }

  List<QrWorkflowStep> get availableSteps {
    final steps = <QrWorkflowStep>[];
    var step = currentStep;

    do {
      steps.add(step);
      if (!canProceedToNextStep && step == currentStep) break;
      if (!canProceedToNextStep) break;
      step = step.next ?? QrWorkflowStep.complete;
    } while (true);

    return steps;
  }

  bool isStepCompleted(QrWorkflowStep step) {
    switch (step) {
      case QrWorkflowStep.scan:
        return reservationCode != null;
      case QrWorkflowStep.validate:
        return status != null;
      case QrWorkflowStep.tagBags:
        return bagTagGenerated;
      case QrWorkflowStep.capturePhotos:
        return photosCaptured;
      case QrWorkflowStep.storeInWarehouse:
        return warehouseStored;
      case QrWorkflowStep.generatePickupPin:
        return pickupReady;
      case QrWorkflowStep.customerPickupOrDelivery:
        return deliveryCompleted;
      case QrWorkflowStep.complete:
        return deliveryCompleted;
    }
  }

  QrWorkflowState copyWith({
    QrWorkflowStep? currentStep,
    String? reservationId,
    String? reservationCode,
    ReservationStatus? status,
    bool? bagTagGenerated,
    bool? photosCaptured,
    int? photoCount,
    String? bagTagId,
    String? pickupPin,
    bool? warehouseStored,
    bool? pickupReady,
    bool? deliveryCompleted,
    List<String>? validationErrors,
  }) {
    return QrWorkflowState(
      currentStep: currentStep ?? this.currentStep,
      reservationId: reservationId ?? this.reservationId,
      reservationCode: reservationCode ?? this.reservationCode,
      status: status ?? this.status,
      bagTagGenerated: bagTagGenerated ?? this.bagTagGenerated,
      photosCaptured: photosCaptured ?? this.photosCaptured,
      photoCount: photoCount ?? this.photoCount,
      bagTagId: bagTagId ?? this.bagTagId,
      pickupPin: pickupPin ?? this.pickupPin,
      warehouseStored: warehouseStored ?? this.warehouseStored,
      pickupReady: pickupReady ?? this.pickupReady,
      deliveryCompleted: deliveryCompleted ?? this.deliveryCompleted,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

class QrWorkflowNotifier extends StateNotifier<QrWorkflowState> {
  QrWorkflowNotifier() : super(const QrWorkflowState());

  void initializeFromReservation(Reservation reservation) {
    final step = _determineInitialStep(reservation);
    state = QrWorkflowState(
      currentStep: step,
      reservationId: reservation.id,
      reservationCode: reservation.code,
      status: reservation.status,
    );
  }

  QrWorkflowStep _determineInitialStep(Reservation reservation) {
    if (reservation.status == ReservationStatus.stored ||
        reservation.status == ReservationStatus.readyForPickup ||
        reservation.status == ReservationStatus.outForDelivery) {
      return QrWorkflowStep.generatePickupPin;
    }
    if (reservation.status == ReservationStatus.completed) {
      return QrWorkflowStep.complete;
    }
    return QrWorkflowStep.scan;
  }

  bool proceedToNextStep() {
    if (!state.canProceedToNextStep) return false;
    final next = state.currentStep.next;
    if (next == null) return false;
    state = state.copyWith(
      currentStep: next,
      validationErrors: [],
    );
    return true;
  }

  bool canProceedTo(QrWorkflowStep targetStep) {
    if (state.currentStep == targetStep) return true;

    final currentIndex = QrWorkflowStep.values.indexOf(state.currentStep);
    final targetIndex = QrWorkflowStep.values.indexOf(targetStep);

    if (targetIndex <= currentIndex) return false;

    for (var i = currentIndex; i < targetIndex; i++) {
      final step = QrWorkflowStep.values[i];
      if (!state.isStepCompleted(step)) return false;
    }

    return true;
  }

  void setReservationCode(String code) {
    state = state.copyWith(reservationCode: code);
  }

  void setReservationStatus(ReservationStatus status) {
    state = state.copyWith(status: status);
  }

  void setBagTagGenerated(String bagTagId) {
    state = state.copyWith(
      bagTagGenerated: true,
      bagTagId: bagTagId,
    );
  }

  void setPhotosCaptured(int count) {
    state = state.copyWith(
      photosCaptured: count > 0,
      photoCount: count,
    );
  }

  void setWarehouseStored() {
    state = state.copyWith(warehouseStored: true);
  }

  void setPickupReady(String pin) {
    state = state.copyWith(
      pickupReady: true,
      pickupPin: pin,
    );
  }

  void setDeliveryCompleted() {
    state = state.copyWith(deliveryCompleted: true);
  }

  void addValidationError(String error) {
    state = state.copyWith(
      validationErrors: [...state.validationErrors, error],
    );
  }

  void clearValidationErrors() {
    state = state.copyWith(validationErrors: []);
  }

  void reset() {
    state = const QrWorkflowState();
  }
}

final qrWorkflowProvider =
    StateNotifierProvider<QrWorkflowNotifier, QrWorkflowState>(
  (ref) => QrWorkflowNotifier(),
);

final canProceedToTagBagsProvider = Provider<bool>((ref) {
  final workflow = ref.watch(qrWorkflowProvider);
  return workflow.reservationCode != null &&
      workflow.status != null &&
      (workflow.status == ReservationStatus.confirmed ||
          workflow.status == ReservationStatus.checkinPending);
});

final canProceedToPhotosProvider = Provider<bool>((ref) {
  final workflow = ref.watch(qrWorkflowProvider);
  return workflow.bagTagGenerated && workflow.bagTagId != null;
});

final canProceedToStoreProvider = Provider<bool>((ref) {
  final workflow = ref.watch(qrWorkflowProvider);
  return workflow.photosCaptured && workflow.photoCount > 0;
});

final canProceedToPinProvider = Provider<bool>((ref) {
  final workflow = ref.watch(qrWorkflowProvider);
  return workflow.warehouseStored;
});

final workflowProgressProvider = Provider<double>((ref) {
  final workflow = ref.watch(qrWorkflowProvider);
  final completedSteps = QrWorkflowStep.values
      .takeWhile((step) =>
          step == QrWorkflowStep.complete ||
          workflow.isStepCompleted(step))
      .length;
  return completedSteps / QrWorkflowStep.values.length;
});

final currentStepLabelProvider = Provider<String>((ref) {
  final workflow = ref.watch(qrWorkflowProvider);
  return workflow.currentStep.label;
});

final pendingStepsProvider = Provider<List<QrWorkflowStep>>((ref) {
  final workflow = ref.watch(qrWorkflowProvider);
  return QrWorkflowStep.values
      .where((step) => !workflow.isStepCompleted(step))
      .toList();
});
