import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _pdfController.zoomLevel += 0.5,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              if (_pdfController.zoomLevel > 0.5) {
                _pdfController.zoomLevel -= 0.5;
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.network(
            widget.pdfUrl,
            controller: _pdfController,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() => _isLoading = false);
            },
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi tải PDF: ${details.error}')),
              );
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}