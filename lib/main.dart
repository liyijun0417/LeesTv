import 'dart:async';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';
import 'package:wakelock/wakelock.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: []); //隐藏状态栏，底部按钮栏
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      home: const VideoScreen(),
    ),
  );
}

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final FijkPlayer player = FijkPlayer();
  int current = 0;

  var myList = [];

  @override
  initState() {
    super.initState();
    Wakelock.enable(); //播放途中防止熄屏
    _getData();
    // _PlayerSetting();
  }

  /**
    * 播放设置
    */
  _PlayerSetting() {
    _Alter(myList[current]['name']!);
    player.setDataSource(myList[current]['url']!, autoPlay: true);
    player.setOption(FijkOption.playerCategory, "fflags", 'nobuffer');
    player.setOption(FijkOption.playerCategory, "fast", 1);
    player.setOption(FijkOption.playerCategory, "framedrop", 5);
    player.setOption(FijkOption.playerCategory, "start-on-prepared", 1);
    player.setOption(FijkOption.formatCategory, "max-buffer-size", 0);
    player.setOption(FijkOption.playerCategory, "packet-buffering", 0);
    player.setOption(FijkOption.formatCategory, "analyzeduration", 1);
    player.setOption(FijkOption.formatCategory, "analyzemaxduration", 100);
    player.setOption(FijkOption.formatCategory, "rtsp_transport", 'tcp');
    player.setOption(FijkOption.formatCategory, "probesize", 100);
    player.setOption(FijkOption.formatCategory, "flush_packets", 0);
    player.setOption(FijkOption.playerCategory, "reconnect", 5);
    player.setOption(FijkOption.playerCategory, "dns_cache_clear", 1);
  }

  Future<void> _getData() async {
    Dio dio = Dio();
    try {
      // 发起GET请求
      Response response =
          await dio.get('https://ai.mufengweilai.com/api/index/movie');
      // 请求成功时的处理代码
      Map<String, dynamic> res = response.data;
      if (res['code'] == 1) {
        setState(() {
          for (var item in res['data']) {
            myList.add(item);
          }
        });
      }
      _PlayerSetting();
    } catch (error) {
      // 请求失败时的处理代码
      print('Error: $error');
    }
  }

  //下一台
  void _next() {
    setState(() async {
      if (current == (myList.length - 1)) {
        current = 0;
      } else {
        current++;
      }
      _Alter(myList[current]['name']!);
      await player.reset();
      await player.setDataSource(myList[current]['url']!);
      await player.prepareAsync();
    });
  }

  //上一台
  void _prev() {
    setState(() async {
      if (current == 0) {
        current = myList.length;
      } else {
        current--;
      }
      _Alter(myList[current]['name']!);
      await player.reset();
      await player.setDataSource(myList[current]['url']!);
      await player.prepareAsync();
    });
  }

  //菜单
  List<PopupMenuEntry> _menu() {
    List<PopupMenuEntry> menuItems = [];
    myList.forEach((value) {
      menuItems.add(
        PopupMenuItem(
          value: value['url'],
          child: Text(value['name']!),
        ),
      );
    });
    return menuItems;
  }

  /**
     * 电视视图
     */
  Widget _TvViews() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      color: Colors.transparent,
      alignment: Alignment.center,
      child: FijkView(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          player: player,
          fit: FijkFit.fill),
    );
  }

  /**
     * 节目列表
     */
  _TvList() {
    return showMenu(
        context: context,
        position: RelativeRect.fromLTRB(0, 0, 100, 100),
        items: List.generate(
          myList.length,
          (index) {
            return PopupMenuItem(
                  value: myList[index],
                  child: Center(child: Opacity(opacity: 0.5,child: Text(myList[index]['name']!))),
                  onTap: () => {
                    setState(() async {
                      current = index;
                      _Alter(myList[index]['name']!);
                      await player.reset();
                      await player.setDataSource(myList[index]['url']!);
                      await player.prepareAsync();
                    })
                  },
                );
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    if (myList.length > 0) {
      return RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: (value) {
            //debugPrint("遥控器：${value.data}");
            if (value.data is RawKeyEventDataAndroid) {
              var key = value.data as RawKeyEventDataAndroid;
              if (key.flags == 520) {
                //上19 下20 左21 右22 // 8是遥控器按下，520是遥控器 弹起
                if (key.keyCode == 19) {
                  //方向上
                  _prev();
                } else if (key.keyCode == 20) {
                  //方向下
                  _next();
                } else if (key.keyCode == 21) {
                  //方向左
                  _TvList();
                } else if (key.keyCode == 22) {
                  //方向右
                  showCustomDialog(context);
                } else if (key.keyCode == 23) {
                  //确认按键,弹菜单
                }
              }
            }
          },
          child: Center(
            child: Scaffold(
                body: Stack(children: [
              //手机遥控器
              GestureDetector(
                onLongPress: _TvList,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    _prev(); //下滑
                  } else if (details.primaryVelocity! < 0) {
                    _next(); //上滑
                  } else {
                    showCustomDialog(context);
                  }
                },
                //视频显示容器
                child: _TvViews(),
              )
            ])),
          ));
    } else {
      return Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          color: Colors.white,
          child: const Text("正在启动,请稍等片刻...",style: TextStyle(color: Colors.black38,decoration: TextDecoration.none))
          )
        );
    }
  }

  /**
   * 弹窗封装，有点神奇，明明设置了位置和颜色啥的，但是就是不生效
   */
  void _Alter(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP_RIGHT,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.blue,
    );
  }

  /**
   * 联系我们确认框
   */
  showCustomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                "https://ai.mufengweilai.com/img/contacts.png",
                width: 280,
                height: 280,
                fit: BoxFit.cover,
              ), // 你可以替换成你自己的图片路径

              const Text('如若发生故障,请添加开发人员微信处理'),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    player.release();
  }
}
