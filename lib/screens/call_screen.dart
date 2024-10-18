// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';

import 'package:document_analyser_poc_new/services/signalling_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import 'dart:html' as html;

class CallScreen extends StatefulWidget {
  final String callerId, calleeId;
  final dynamic offer;
  const CallScreen({
    super.key,
    this.offer,
    required this.callerId,
    required this.calleeId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final socket = SignallingService.instance.socket;

  MediaStream? _localStream;

  final _remoteRTCVideoRenderer = RTCVideoRenderer();

  RTCPeerConnection? _rtcPeerConnection;

  List<RTCIceCandidate> rtcIceCadidates = [];

  bool isAudioOn = true;

  final mediaRecorder = MediaRecorder();

  @override
  void initState() {
    _setupPeerConnection();
    super.initState();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  Future<Uint8List> _blobToUint8List(html.Blob blob) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoad.first;
    return reader.result as Uint8List;
  }

  _sendAudioChunks(MediaStream stream, String userId) {
    if (kIsWeb) {
      mediaRecorder.startWeb(
        _localStream!,
        onDataChunk: (blob, isLastOne) async {
          Uint8List audioChunk = await _blobToUint8List(blob);

          socket!.emit(
              'audio_chunk', {"audioChunk": audioChunk, "callerId": userId});

          if (isLastOne) {
            print('This was the last chunk');
          }
        },
      );
    }
  }

  _setupPeerConnection() async {
    // create peer connection
    _rtcPeerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    });

    _rtcPeerConnection!.onTrack = (event) {
      print('Remote track received: ${event.track.kind}');

      if (event.track.kind == 'audio') {
        _remoteRTCVideoRenderer.srcObject = event.streams[0];
      }

      setState(() {});
    };

    // get localStream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': isAudioOn,
      'video': false,
    });

    // add mediaTrack to peerConnection
    _localStream!.getTracks().forEach((track) {
      _rtcPeerConnection!.addTrack(track, _localStream!);
    });

    // send audio chunks for signalling
    if (widget.offer != null) {
      _sendAudioChunks(_localStream!, widget.callerId);
      await _handleIncomingCall();
    } else {
      _sendAudioChunks(_localStream!, widget.calleeId);
      await _handleOutgoingCall();
    }
  }

  Future<void> _handleIncomingCall() async {
    // Listen for remote IceCandidate
    print('Incoming call...');
    socket!.on("ice_candidate", (data) {
      print('ice_candidate_event');
      print(data);
      String candidate = data["iceCandidate"]["candidate"];
      String sdpMid = data["iceCandidate"]["id"];
      int sdpMLineIndex = data["iceCandidate"]["label"];

      _rtcPeerConnection!.addCandidate(RTCIceCandidate(
        candidate,
        sdpMid,
        sdpMLineIndex,
      ));
    });

    await _rtcPeerConnection!.setRemoteDescription(
      RTCSessionDescription(widget.offer["sdp"], widget.offer["type"]),
    );

    RTCSessionDescription answer = await _rtcPeerConnection!.createAnswer();

    await _rtcPeerConnection!.setLocalDescription(answer);

    socket!.emit("answer_call", {
      "callerId": widget.callerId,
      "sdpAnswer": answer.toMap(),
    });
  }

  Future<void> _handleOutgoingCall() async {
    print('Outgoing call...');
    _rtcPeerConnection!.onIceCandidate =
        (RTCIceCandidate candidate) => rtcIceCadidates.add(candidate);

    socket!.on("call_answered", (data) async {
      await _rtcPeerConnection!.setRemoteDescription(
        RTCSessionDescription(
          data["sdpAnswer"]["sdp"],
          data["sdpAnswer"]["type"],
        ),
      );

      for (RTCIceCandidate candidate in rtcIceCadidates) {
        socket!.emit("ice_candidate", {
          "calleeId": widget.calleeId,
          "iceCandidate": {
            "id": candidate.sdpMid,
            "label": candidate.sdpMLineIndex,
            "candidate": candidate.candidate,
          },
        });
      }
    });

    RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();

    await _rtcPeerConnection!.setLocalDescription(offer);

    socket!.emit('make_call', {
      "calleeId": widget.calleeId,
      "sdpOffer": offer.toMap(),
    });
  }

  _leaveCall() async {
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });

    await _rtcPeerConnection?.close();
    _rtcPeerConnection = null;

    socket?.disconnect();

    if (context.mounted) {
      context.push('/dashboard');
    }
  }

  _toggleMic() {
    isAudioOn = !isAudioOn;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("P2P Call App"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: Center(
                child: Text('Audio Call Active'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(isAudioOn ? Icons.mic : Icons.mic_off),
                    onPressed: _toggleMic,
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_end),
                    iconSize: 30,
                    onPressed: _leaveCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _remoteRTCVideoRenderer.dispose();
    _localStream?.dispose();
    _rtcPeerConnection?.dispose();
    super.dispose();
  }
}
