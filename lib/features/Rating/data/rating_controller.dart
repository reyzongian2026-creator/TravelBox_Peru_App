import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelbox_peru_app/core/network/api_client.dart';
import 'package:travelbox_peru_app/features/Rating/data/rating_model.dart';
import 'package:travelbox_peru_app/features/Rating/data/rating_repository.dart';

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return RatingRepository(dio: dio);
});

final ratingControllerProvider = ChangeNotifierProvider.autoDispose<RatingController>((ref) {
  final repository = ref.watch(ratingRepositoryProvider);
  return RatingController(repository);
});

class RatingController extends ChangeNotifier {
  final RatingRepository _repository;

  List<RatingModel> _ratings = [];
  WarehouseRatingSummary? _summary;
  RatingModel? _myRating;
  bool _isLoading = false;
  String? _error;
  int? _selectedStars = 0;
  String _comment = '';

  RatingController(this._repository);

  List<RatingModel> get ratings => _ratings;
  WarehouseRatingSummary? get summary => _summary;
  RatingModel? get myRating => _myRating;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get selectedStars => _selectedStars;
  String get comment => _comment;
  bool get hasRated => _myRating != null;

  void setStars(int stars) {
    _selectedStars = stars;
    notifyListeners();
  }

  void setComment(String comment) {
    _comment = comment;
    notifyListeners();
  }

  Future<void> loadRatings(int warehouseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _ratings = await _repository.getRatingsByWarehouse(warehouseId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSummary(int warehouseId) async {
    try {
      _summary = await _repository.getWarehouseSummary(warehouseId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> loadMyRating(int warehouseId) async {
    try {
      _myRating = await _repository.getMyRating(warehouseId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<bool> submitRating({
    required int warehouseId,
    int? reservationId,
  }) async {
    if (_selectedStars == null || _selectedStars == 0) {
      _error = 'Please select a rating';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newRating = await _repository.createRating(
        warehouseId: warehouseId,
        reservationId: reservationId,
        stars: _selectedStars!,
        comment: _comment.isNotEmpty ? _comment : null,
      );
      _myRating = newRating;
      _ratings.insert(0, newRating);
      _selectedStars = 0;
      _comment = '';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _ratings = [];
    _summary = null;
    _myRating = null;
    _isLoading = false;
    _error = null;
    _selectedStars = 0;
    _comment = '';
    notifyListeners();
  }
}
