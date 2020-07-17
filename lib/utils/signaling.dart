import 'package:flutter_webrtc/webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart';

typedef OnlocalStream(MediaStream stream);
typedef OnRemoteStream(MediaStream stream);
typedef OnJoined(bool isOk);

class Signaling {
  Socket _socket;
  OnlocalStream onlocalStream;
  OnRemoteStream onRemoteStream;
  OnJoined onJoined;
  RTCPeerConnection _peer;
  MediaStream _localStream;

  String _him;

  init() async {
    MediaStream stream = await navigator.getUserMedia({
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth": '640',
          "minHeight": '480',
          "minFrameRate": '30',
        },
        "facingMode": "user",
        "optional": [],
      }
    });
    _localStream = stream;
    onlocalStream(stream);
    _connect();
  }

  _createPeer() async {
    this._peer = await createPeerConnection({
      "iceServers": [
        {
          "urls": ['stun:stun1.l.google.com:19302']
        }
      ]
    }, {});
    await _peer.addStream(_localStream);
    _peer.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate == null) {
        return;
      }
      print("send the iceCandidate");
      //send the iceCandidate

      emit('candidate', {"username":_him,"candidate":candidate.toMap()});
    };
    _peer.onAddStream = (MediaStream remoteStream) {
      onRemoteStream(remoteStream);
    };
  }

  _connect() {
    _socket =
        io('https://backend-simple-webrtc.herokuapp.com', <String, dynamic>{
      'transports': ['websocket'],
    });

    _socket.on('on-join', (isOk) {
      print('on-join lalala');
      onJoined(isOk);
    });

    _socket.on('on-call', (data) async {
      print('on-call $data');
      await _createPeer();
      final String username = data['username'];
      _him = username;
      final offer = data['offer'];
      final RTCSessionDescription desc =
          RTCSessionDescription(offer['sdp'], offer['type']);

      await _peer.setRemoteDescription(desc);

      final sdpConstraints = {
        "mandatory": {
          "OfferToReciveAudio": true,
          "OfferToReciveVideo": true,
        },
        "optional": [],
      };

      final RTCSessionDescription answer =
          await _peer.createAnswer(sdpConstraints);
      await _peer.setLocalDescription(answer);

      emit('answer', {"username": _him, "answer": answer.toMap()});
    });

    _socket.on('on-answer', (answer) {
      print("on-answer $answer");
      final RTCSessionDescription desc =
          RTCSessionDescription(answer['sdp'], answer['type']);
      _peer.setRemoteDescription(desc);
    });


    _socket.on('on-candidate', (data) async{
      print("on-candidate $data");
      final RTCIceCandidate candidate = RTCIceCandidate(data['candidate'],data['sdpMid'], data['sdpMLineIndex']);
      
      await _peer.addCandidate(candidate);
    });
  }

  emit(String eventName, dynamic data) {
    _socket?.emit(eventName, data);
  }

  call(String username) async {
    _him=username;
    await _createPeer();
    final sdpConstraints = {
      "mandatory": {
        "OfferToReciveAudio": true,
        "OfferToReciveVideo": true,
      },
      "optional": [],
    };
    final RTCSessionDescription offer = await _peer.createOffer(sdpConstraints);
    _peer.setLocalDescription(offer);
    emit('call', {"username": username, "offer": offer.toMap()});
  }

  dispose() {
    _socket?.disconnect();
  }
}
