import 'dart:io';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'dart:math';

class Luban {
  Luban._();

  static const _DEFAULT_QUALITY = 80;

  static Future<String> compressImage(CompressObject object) async {
    return compute(_lubanCompress, object);
  }

  static String _lubanCompress(CompressObject object) {
    Image image = decodeImage(object.imageFile.readAsBytesSync());
    var length = object.imageFile.lengthSync();
    bool isLandscape = false;

    double size;
    int fixelW = image.width;
    int fixelH = image.height;
    double thumbW = (fixelW % 2 == 1 ? fixelW + 1 : fixelW).toDouble();
    double thumbH = (fixelH % 2 == 1 ? fixelH + 1 : fixelH).toDouble();
    double scale = 0;
    if (fixelW > fixelH) {
      scale = fixelH / fixelW;
      var tempFixelH = fixelW;
      var tempFixelW = fixelH;
      fixelH = tempFixelH;
      fixelW = tempFixelW;
      isLandscape = true;
    } else {
      scale = fixelW / fixelH;
    }

    var decodedImageFile = new File(
        object.path + '/img_${DateTime.now().millisecondsSinceEpoch}.jpg');

    var imageSize = length / 1024;
    if (scale <= 1 && scale > 0.5625) {
      if (fixelH < 1664) {
        if (imageSize < 150) {
          decodedImageFile
              .writeAsBytesSync(encodeJpg(image, quality: _DEFAULT_QUALITY));
          return decodedImageFile.path;
        }
        size = (fixelW * fixelH) / pow(1664, 2) * 150;
        size = size < 60 ? 60 : size;
      } else if (fixelH >= 1664 && fixelH < 4990) {
        thumbW = fixelW / 2;
        thumbH = fixelH / 2;
        size = (thumbH * thumbW) / pow(2495, 2) * 300;
        size = size < 60 ? 60 : size;
      } else if (fixelH >= 4990 && fixelH < 10240) {
        thumbW = fixelW / 4;
        thumbH = fixelH / 4;
        size = (thumbW * thumbH) / pow(2560, 2) * 300;
        size = size < 100 ? 100 : size;
      } else {
        int multiple = fixelH / 1280 == 0 ? 1 : (fixelH / 1280).toInt();
        thumbW = fixelW / multiple;
        thumbH = fixelH / multiple;
        size = (thumbW * thumbH) / pow(2560, 2) * 300;
        size = size < 100 ? 100 : size;
      }
    } else if (scale <= 0.5625 && scale >= 0.5) {
      if (fixelH < 1280 && imageSize < 200) {
        decodedImageFile
            .writeAsBytesSync(encodeJpg(image, quality: _DEFAULT_QUALITY));
        return decodedImageFile.path;
      }
      int multiple = fixelH / 1280 == 0 ? 1 : (fixelH / 1280).toInt();
      thumbW = fixelW / multiple;
      thumbH = fixelH / multiple;
      size = (thumbW * thumbH) / (1440.0 * 2560.0) * 200;
      size = size < 100 ? 100 : size;
    } else {
      int multiple = (fixelH / (1280.0 / scale)).ceil();
      thumbW = fixelW / multiple;
      thumbH = fixelH / multiple;
      size = ((thumbW * thumbH) / (1280.0 * (1280 / scale))) * 500;
      size = size < 100 ? 100 : size;
    }
    if (imageSize < size) {
      decodedImageFile
          .writeAsBytesSync(encodeJpg(image, quality: _DEFAULT_QUALITY));
      return decodedImageFile.path;
    }
    Image smallerImage;
    if (isLandscape) {
      smallerImage = copyResize(image, thumbH.toInt(), thumbW.toInt());
    } else {
      smallerImage = copyResize(image, thumbW.toInt(), thumbH.toInt());
    }
    if (decodedImageFile.existsSync()) {
      decodedImageFile.deleteSync();
    }
    if (object.mode == CompressMode.LARGE2SMALL) {
      _large2SmallCompressImage(
          smallerImage, decodedImageFile, _DEFAULT_QUALITY, size);
    } else if (object.mode == CompressMode.SMALL2LARGE) {
      _small2LargeCompressImage(smallerImage, decodedImageFile, 6, size);
    } else {
      if (imageSize < 500) {
        _large2SmallCompressImage(
            smallerImage, decodedImageFile, _DEFAULT_QUALITY, size);
      } else {
        _small2LargeCompressImage(smallerImage, decodedImageFile, 6, size);
      }
    }
    return decodedImageFile.path;
  }

  static _large2SmallCompressImage(
      Image image, File file, quality, targetSize) {
    var im = encodeJpg(image, quality: quality);
    var tempImageSize = Uint8List.fromList(im).lengthInBytes;
    if (tempImageSize / 1024 > targetSize && quality > 6) {
      quality -= 6;
      _large2SmallCompressImage(image, file, quality, targetSize);
      return;
    }
    file.writeAsBytesSync(im);
  }

  static _small2LargeCompressImage(
      Image image, File file, quality, targetSize) {
    var im = encodeJpg(image, quality: quality);
    var tempImageSize = Uint8List.fromList(im).lengthInBytes;
    if (tempImageSize / 1024 < targetSize && quality <= 100) {
      quality += 6;
      _small2LargeCompressImage(image, file, quality, targetSize);
      return;
    }
    file.writeAsBytesSync(im);
  }
}

enum CompressMode {
  SMALL2LARGE,
  LARGE2SMALL,
  AUTO,
}

class CompressObject {
  File imageFile;
  String path;
  CompressMode mode;

  CompressObject({this.imageFile, this.path, this.mode: CompressMode.AUTO});
}
