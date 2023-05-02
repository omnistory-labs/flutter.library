import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:omnitalk_sdk/omnitalk_sdk.dart';
import 'package:sample/screen/home_screen.dart';

class VideoConferenceDemo extends StatefulWidget {
  const VideoConferenceDemo({super.key});

  @override
  State<VideoConferenceDemo> createState() => _VideoConferenceDemoState();
}

class _VideoConferenceDemoState extends State<VideoConferenceDemo> {
  Omnitalk omnitalk;
  String sessionId = '';
  String _roomSubject = ' ';
  String? selectedRoomId = ' ';
  var roomId;
  List<dynamic> _roomList = [];
  List partiList = [];

  RTCVideoRenderer localVideo = RTCVideoRenderer();
  RTCVideoRenderer remoteVideo1 = RTCVideoRenderer();
  RTCVideoRenderer remoteVideo2 = RTCVideoRenderer();
  RTCVideoRenderer remoteVideo3 = RTCVideoRenderer();
  List<RTCVideoRenderer> renderers = [];
  int count = 1;
  List<bool> flags = [false, false, false];


  var _futureRoomList;
  Timer? _debounce;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode focusnode = FocusNode();
  bool isDropdonwSelected = false;
  bool isBroadcastingStarted = false;
  

  _VideoConferenceDemoState()
      : omnitalk = Omnitalk("FM51-HITX-IBPG-QN7H", "FWIWblAEXpbIims") {
    omnitalk.onmessage = (event) async {
      switch (event["cmd"]) {
        case "SESSION_EVENT":
          print('Session started ${event["session"]}');
          break;
        case "BROADCASTING_EVENT":
          await omnitalk.subscribe(
              publish_idx: event["publish_idx"],
              remoteRenderer: renderers[count]);
          setState(() {
            count++;
          });
          break;
        case "ONAIR_EVENT":
          print(event["track_type"]);
          break;
        case "LEAVE_EVENT":
          print('Session closed ${event["session"]}');
          break;
      }
    };
    renderers = [localVideo, remoteVideo1, remoteVideo2, remoteVideo3];
  }

  _onCreateSession() async {
    await omnitalk.getPermission();
    var session = await omnitalk.createSession();

    sessionId = session["session"];
    
    return await omnitalk.roomList();
  }


  _onJoinRoom() async {
    await omnitalk.joinRoom(room_id: selectedRoomId);
  }

  _onCreateJoinRoom() async {
    var roomObj = await omnitalk.createRoom(subject: _roomSubject);
    roomId = roomObj?["room_id"];
    await omnitalk.joinRoom(room_id: roomId);
    isDropdonwSelected = true;
  }

  _onLeave() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );

    await omnitalk.leave(sessionId);
    _inputController.dispose();
    await localVideo.dispose();
  }

  _buildVideoItems(int count) {
    List<Widget> items = [];
    for (int i = 0; i < count; i++) {
      items.add(RTCVideoView(
        renderers[i],
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        mirror: i == 0 ? true : false,
      ));
    }
    return items;
  }

  _onPubSub() async {
    await omnitalk.publish(localRenderer: localVideo);
    var partiResult = await omnitalk.partiList(roomId);
    print("---------partiList-------");
    print(partiResult);

    for (var parti in partiResult) {
      int pubIdx = parti["publish_idx"];
      partiList.add(pubIdx);
    }

    for (int i = 0; i < partiList.length; i++) {
      int pubIdx = partiList[i];
      await omnitalk.subscribe(
          publish_idx: pubIdx, remoteRenderer: renderers[i + 1]);
      count++;
    }
    setState(() {
      renderers;
    });
  }

  _onCreateNewRoom() async {
    setState(() {
      isDropdonwSelected = true;
      _roomSubject = _inputController.text;
    });
    await _onCreateJoinRoom();
    focusnode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
  }

  void _onInputChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {});
  }

  @override
  void initState() {
    super.initState();
    _futureRoomList = _onCreateSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            "Video Conference",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          actions: <Widget>[
            IconButton(
              onPressed: () async {
                await _onLeave();
              },
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Leave',
            )
          ],
          backgroundColor: Colors.white,
          foregroundColor: Colors.orange[900],
        ),
        body: FutureBuilder(
          future: _futureRoomList,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              final dynamic data = snapshot.data ?? [];
              List<dynamic> roomList = data is List ? data : [];
              return Container(
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    const SizedBox(
                      height: 17,
                    ),
                    DropdownButton(
                      hint: const Text('Select a room'),
                      value: roomList
                              .any((item) => item["room_id"] == selectedRoomId)
                          ? selectedRoomId
                          : null,
                      items: roomList.isNotEmpty
                          ? roomList.map((item) {
                              return DropdownMenuItem(
                                value: item["room_id"],
                                child: Text(item["subject"]),
                              );
                            }).toList()
                          : null,
                      onChanged: (value) {
                        setState(() {
                          selectedRoomId = value as String;
                        });
                        _onJoinRoom();
                        isDropdonwSelected = true;
                        roomId = selectedRoomId;
                      },
                      iconEnabledColor: Colors.orange,
                      iconDisabledColor: Colors.grey,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _inputController,
                        focusNode: focusnode,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.recommend_rounded),
                            hintText: 'Enter Room Subject',
                            contentPadding: EdgeInsets.symmetric(vertical: 16)),
                        onChanged: (value) {
                          _onInputChanged();
                        },
                        enabled: !isDropdonwSelected,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    ElevatedButton(
                      onPressed: isDropdonwSelected
                          ? null
                          : () {
                              _onCreateNewRoom();
                            },
                      style: ButtonStyle(
                        backgroundColor: isDropdonwSelected
                            ? MaterialStateProperty.all<Color>(Colors.grey)
                            : MaterialStateProperty.all<Color>(
                                Colors.deepOrangeAccent),
                        minimumSize: MaterialStateProperty.all<Size>(
                            const Size(150, 50)),
                      ),
                      child: const Text('Create Room'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _onPubSub();

                        setState(() {
                          isBroadcastingStarted = true;
                          isDropdonwSelected = true;
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor: isBroadcastingStarted
                            ? MaterialStateProperty.all<Color>(Colors.grey)
                            : MaterialStateProperty.all<Color>(
                                Colors.deepOrangeAccent),
                        minimumSize: MaterialStateProperty.all<Size>(
                            const Size(150, 50)),
                      ),
                      child: const Text('Start Conference'),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      children: _buildVideoItems(4),
                    )
                  ],
                ),
              );
            }
          },
        ));
  }
}
