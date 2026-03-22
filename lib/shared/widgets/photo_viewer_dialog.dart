import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/widgets/app_smart_image.dart';

class PhotoViewerDialog extends StatefulWidget {
  const PhotoViewerDialog({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.title,
  });

  final String imageUrl;
  final String? heroTag;
  final String? title;

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String? heroTag,
    String? title,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => PhotoViewerDialog(
        imageUrl: imageUrl,
        heroTag: heroTag,
        title: title,
      ),
    );
  }

  @override
  State<PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<PhotoViewerDialog>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.addListener(_onAnimationChanged);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onAnimationChanged() {
    if (_animation != null) {
      _transformationController.value = _animation!.value;
    }
  }

  void _resetZoom() {
    _animateTo(
      Matrix4.identity(),
      Matrix4.identity().scaled(2.0, 2.0),
    );
  }

  void _animateTo(Matrix4 from, Matrix4 to) {
    _animation = Matrix4Tween(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward(from: 0);
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.5) {
      _animateTo(
        _transformationController.value,
        Matrix4.identity(),
      );
    } else {
      _animateTo(
        _transformationController.value,
        Matrix4.identity().scaled(2.5, 2.5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final currentScale = _transformationController.value.getMaxScaleOnAxis();
        if (currentScale > 1.1) {
          _animateTo(
            _transformationController.value,
            Matrix4.identity(),
          );
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
          ),
          title: widget.title != null
              ? Text(
                  widget.title!,
                  style: const TextStyle(color: Colors.white),
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.zoom_out_map, color: Colors.white),
              tooltip: 'Reset zoom',
              onPressed: () {
                HapticFeedback.lightImpact();
                _resetZoom();
              },
            ),
          ],
        ),
        body: Center(
          child: Hero(
            tag: widget.heroTag ?? widget.imageUrl,
            child: GestureDetector(
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: _minScale,
                maxScale: _maxScale,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: AppSmartImage(
                  source: widget.imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhotoGalleryView extends StatelessWidget {
  const PhotoGalleryView({
    super.key,
    required this.images,
    required this.initialIndex,
    this.titles,
  });

  final List<String> images;
  final int initialIndex;
  final List<String>? titles;

  static Future<void> show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    List<String>? titles,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => PhotoGalleryView(
        images: images,
        initialIndex: initialIndex,
        titles: titles,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PhotoGalleryDialog(
      images: images,
      initialIndex: initialIndex,
      titles: titles,
    );
  }
}

class _PhotoGalleryDialog extends StatefulWidget {
  const _PhotoGalleryDialog({
    required this.images,
    required this.initialIndex,
    this.titles,
  });

  final List<String> images;
  final int initialIndex;
  final List<String>? titles;

  @override
  State<_PhotoGalleryDialog> createState() => _PhotoGalleryDialogState();
}

class _PhotoGalleryDialogState extends State<_PhotoGalleryDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => PhotoViewerDialog.show(
                  context,
                  imageUrl: widget.images[index],
                  heroTag: 'gallery_${widget.images[index]}',
                  title: widget.titles?[index],
                ),
                child: Center(
                  child: Hero(
                    tag: 'gallery_${widget.images[index]}',
                    child: AppSmartImage(
                      source: widget.images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white38,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: Text(
              '${_currentIndex + 1} / ${widget.images.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
