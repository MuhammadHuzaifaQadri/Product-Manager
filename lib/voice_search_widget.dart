import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceSearchWidget extends StatefulWidget {
  final Function(String) onResult;
  
  const VoiceSearchWidget({Key? key, required this.onResult}) : super(key: key);

  @override
  State<VoiceSearchWidget> createState() => _VoiceSearchWidgetState();
}

class _VoiceSearchWidgetState extends State<VoiceSearchWidget> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
            if (_text.isNotEmpty) {
              widget.onResult(_text);
            }
          }
        },
        onError: (error) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error.errorMsg}'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _text = '';
        });

        _speech.listen(
          onResult: (result) {
            setState(() {
              _text = result.recognizedWords;
            });
          },
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          localeId: 'en_US',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_text.isNotEmpty) {
        widget.onResult(_text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _listen,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.red : Colors.blue,
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(_animationController.value),
                            blurRadius: 20 * _animationController.value,
                            spreadRadius: 10 * _animationController.value,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 40,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isListening ? 'Listening...' : 'Tap to speak',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _isListening ? Colors.red : Colors.grey[700],
          ),
        ),
        if (_text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _text,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

// Voice Search Dialog
void showVoiceSearchDialog(BuildContext context, Function(String) onSearch) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Voice Search',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            VoiceSearchWidget(
              onResult: (text) {
                Navigator.pop(context);
                onSearch(text);
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Try saying: "Show electronics" or "Find laptop"',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}