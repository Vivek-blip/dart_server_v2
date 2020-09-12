import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

class SocketFileShare {
  Map<WebSocket, int> file_shared_count;
  String application_path;
  String base64_encode_cache_songicon = '';
  String base64_encode_cache_fileicon = '';

  SocketFileShare() {
    file_shared_count = {};
    getapplicationDirectory();
  }

  void getapplicationDirectory() async {
    Directory directory = await getApplicationDocumentsDirectory();
    application_path = directory.path;
    print(application_path);
  }

  int checkfileSharedCount(WebSocket wbs) {
    if (file_shared_count != null && file_shared_count[wbs] != null) {
      return file_shared_count[wbs];
    } else {
      return 0;
    }
  }

  Future<String> generateThumbnail(String path) async {
    Uint8List uint8list = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 70,
        maxWidth: 70,
        quality: 70);
    return base64.encode(uint8list);
  }

  Future imageCompressor(String path) async {
    if (lookupMimeType(path).split('/')[0] == 'video') {
      return await generateThumbnail(path);
    } else {
      File compressedFile;
      int filesize = await File(path).length();
      if (filesize > 1000000) {
        compressedFile =
            await FlutterNativeImage.compressImage(path, quality: 40);
        return compressedFile;
      } else {
        compressedFile = File(path);
        return compressedFile;
      }
    }
  }

  void sendFileShare(WebSocket socket, Map files, String type) async {
    int start = 0;
    int finish = 0;
    bool first_file = true;
    int count = 0;
    int currentShareCount = 0;
    int filesharedcount = checkfileSharedCount(socket);
    if (files != null) {
      for (String key in files.keys.toList()) {
        String value = files[key];
        String bas64_encoded;
        print(lookupMimeType(value));
        if (count >= filesharedcount) {
          if (lookupMimeType(value) != null) {
            switch (lookupMimeType(value).split('/')[0]) {
              case 'image':
                Uint8List encoded_data =
                    await imageCompressor(value).then((value) {
                  return value.readAsBytes();
                });
                bas64_encoded = base64.encode(encoded_data);
                break;
              case 'video':
                bas64_encoded = await generateThumbnail(value);
                break;
              case 'audio':
                bas64_encoded = base64_encode_cache_songicon.isEmpty
                    ? base64.encode(
                        (await rootBundle.load('Assets/song_icon.png'))
                            .buffer
                            .asUint8List())
                    : base64_encode_cache_songicon;
                base64_encode_cache_songicon = bas64_encoded;
                break;
              default:
                bas64_encoded = base64_encode_cache_fileicon.isEmpty
                    ? base64.encode(
                        (await rootBundle.load('Assets/file_icon.png'))
                            .buffer
                            .asUint8List())
                    : base64_encode_cache_fileicon;
                base64_encode_cache_fileicon = bas64_encoded;
                break;
            }
          } else {
            bas64_encoded = base64_encode_cache_fileicon.isEmpty
                ? base64.encode((await rootBundle.load('Assets/file_icon.png'))
                    .buffer
                    .asUint8List())
                : base64_encode_cache_fileicon;
            base64_encode_cache_fileicon = bas64_encoded;
          }

          Map<String, String> socketmessgae = {};
          socketmessgae.addAll(
              {"type": "$type", "data": bas64_encoded, 'filename': key});
          socket.add(jsonEncode(socketmessgae));
          if (first_file) {
            Map<String, String> download_msg = {};
            download_msg.addAll({"type": "downloadpermission", "data": 'true'});
            await Future.delayed(Duration(milliseconds: 1000));
            socket.add(jsonEncode(download_msg));
          }
          first_file = false;
          currentShareCount += 1;
        }
        count += 1;
      }
      if (file_shared_count[socket] != null) {
        file_shared_count.update(socket, (value) {
          return value + currentShareCount;
        });
      } else {
        file_shared_count.addAll({socket: currentShareCount});
      }
      print(file_shared_count);
    }
  }
}