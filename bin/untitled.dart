import 'dart:io';
import 'package:image/image.dart';

void main() {
  final extensions = ['png', 'jpg', 'webp'];
  List<Image> allImages = [];

  for (int i = 1; i <= 1; i++) {
    bool found = false;
    for (var ext in extensions) {
      var file = File('D:\\Backup\\Documents\\xwechat_files\\wxid_qcz4dkvucph222_4e9d\\msg\\file\\2025-11\\comics\\ネバーランドにとらわれて   沦为梦幻岛中永远的囚徒\\第1話\\$i.$ext');
      if (file.existsSync()) {
        var img = decodeImage(file.readAsBytesSync());
        if (img != null) {
          allImages.add(img);
          found = true;
          break;
        }
      }
    }
    if (!found) break;
  }

  if (allImages.isEmpty) {
    print('没有找到任何图片');
    return;
  }

  // 设定统一尺寸
  int targetWidth = 1280;
  int targetHeight = 1807;

  // 尺寸统一函数
  Image resizeOrCrop(Image img, int w, int h) {
    if (img.width == w && img.height == h) return img;

    double aspectRatio = img.width / img.height;
    double targetRatio = w / h;

    if ((aspectRatio - targetRatio).abs() < 0.1) {
      return copyResize(img, width: w, height: h);
    }

    int cropWidth = img.width < w ? img.width : w;
    int cropHeight = img.height < h ? img.height : h;
    int x = (img.width - cropWidth) ~/ 2;
    int y = (img.height - cropHeight) ~/ 2;
    Image cropped = copyCrop(img, x: x, y: y, width: cropWidth, height: cropHeight);
    return copyResize(cropped, width: w, height: h);
  }

  // 拼接函数（兼容 image 4.x）
  void pasteImage(Image target, Image source, int offsetX, int offsetY) {
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        target.setPixel(offsetX + x, offsetY + y, pixel);
      }
    }
  }

  // 间距设置
  int rowGap = 5;
  int colGap = 30;

  // 总图尺寸
  int totalWidth = 3 * targetWidth + 2 * colGap;
  int totalHeight = 3 * targetHeight + 2 * rowGap;

  Image emptyImage = Image(width: targetWidth, height: targetHeight);

  for (int y = 0; y < emptyImage.height; y++) {
    for (int x = 0; x < emptyImage.width; x++) {
      emptyImage.setPixelRgba(x, y, 255, 255, 255, 255);
    }
  }

  // 分组处理
  int groupCount = (allImages.length / 9).ceil();
  for (int g = 0; g < groupCount; g++) {
    List<Image> group = [];

    for (int i = 0; i < 9; i++) {
      int index = g * 9 + i;
      if (index < allImages.length) {
        group.add(resizeOrCrop(allImages[index], targetWidth, targetHeight));
      } else {
        group.add(emptyImage); // 空白填充
      }
    }

    Image canvas = Image(width: totalWidth, height: totalHeight);

    for (int y = 0; y < canvas.height; y++) {
      for (int x = 0; x < canvas.width; x++) {
        canvas.setPixelRgba(x, y, 255, 255, 255, 255); // 白色
      }
    }

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        int index = row * 3 + col;
        int x = col * (targetWidth + colGap);
        int y = row * (targetHeight + rowGap);
        pasteImage(canvas, group[index], x, y);
      }
    }

    File('C:\\Users\\Administrator\\IdeaProjects\\untitled\\output\\output_${g + 1}.png').writeAsBytesSync(encodePng(canvas));
    print('✅ 输出 output_${g + 1}.png');
  }
}
