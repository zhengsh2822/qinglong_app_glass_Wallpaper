import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 通用加密封装：AES-256-GCM + PBKDF2-HMAC-SHA256 口令派生。
///
/// 密文容器格式（二进制）：
/// magic("QLWBK", 5B) + version(1B) + salt(16B) + iv(12B) + 密文（末尾含 16B 认证 tag）。
/// key = PBKDF2-HMAC-SHA256(口令, salt, 20000 轮, 32B)。
class CryptoUtils {
  static const List<int> _magic = [0x51, 0x4C, 0x57, 0x42, 0x4B]; // "QLWBK"
  static const int _version = 1;
  static const int _saltLen = 16;
  static const int _ivLen = 12;
  static const int _keyLen = 32;
  static const int _pbkdf2Rounds = 20000;

  /// 加密任意字节，返回带 magic 头的完整容器。
  ///
  /// 必须在独立 isolate 执行（方案文档 9.2）：pointycastle PBKDF2/GCM 是纯 CPU
  /// 同步运算，payload 大时（账号历史 + 全量 env/config 可达 MB 级）在主 isolate
  /// 跑会整段冻结 UI，表现为"直接卡死"。
  static Future<Uint8List> encryptBytes(Uint8List plain, String passphrase) {
    return Isolate.run(() => _encryptBytesSync(plain, passphrase));
  }

  static Uint8List _encryptBytesSync(Uint8List plain, String passphrase) {
    final salt = _randomBytes(_saltLen);
    final iv = _randomBytes(_ivLen);
    final key = _deriveKey(passphrase, salt);

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final encrypted = cipher.process(plain);

    final out = BytesBuilder();
    out.add(_magic);
    out.addByte(_version);
    out.add(salt);
    out.add(iv);
    out.add(encrypted);
    return out.toBytes();
  }

  /// 解密容器字节，口令错误或容器损坏时抛 Exception（独立 isolate，理由同上）。
  static Future<Uint8List> decryptBytes(
    Uint8List container,
    String passphrase,
  ) {
    return Isolate.run(() => _decryptBytesSync(container, passphrase));
  }

  static Uint8List _decryptBytesSync(Uint8List container, String passphrase) {
    final headerLen = _magic.length + 1 + _saltLen + _ivLen;
    if (container.length <= headerLen) {
      throw Exception("解密失败：备份文件已损坏");
    }
    for (int i = 0; i < _magic.length; i++) {
      if (container[i] != _magic[i]) {
        throw Exception("解密失败：不是本应用生成的备份文件");
      }
    }
    if (container[_magic.length] != _version) {
      throw Exception("解密失败：不支持的备份版本");
    }
    final salt = Uint8List.sublistView(
      container,
      _magic.length + 1,
      _magic.length + 1 + _saltLen,
    );
    final iv = Uint8List.sublistView(
      container,
      _magic.length + 1 + _saltLen,
      headerLen,
    );
    final cipherBody = Uint8List.sublistView(container, headerLen);

    try {
      final key = _deriveKey(passphrase, salt);
      final cipher = GCMBlockCipher(AESEngine());
      cipher.init(
        false,
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );
      return cipher.process(cipherBody);
    } catch (e) {
      throw Exception("解密失败：加密口令错误或文件已损坏");
    }
  }

  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, _pbkdf2Rounds, _keyLen));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  static Uint8List _randomBytes(int len) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(len, (_) => r.nextInt(256)));
  }

  // ==================== 文件分块容器（v2，大文件流式安全） ====================
  //
  // 注意：pointycastle 的 GCMBlockCipher 内部会缓冲全部输入，一次性加密大文件
  // 会造成内存峰值（全量包 .tgz 可达几十上百 MB，曾导致 app 闪退）。
  // v2 容器把文件切成固定大小分块，每块独立 GCM 加密（独立 IV，AAD 绑定块序号），
  // 内存占用只与单块大小相关。
  //
  // 格式：magic(5B) + ver(1B)=2 + salt(16B) + chunkSize(4B LE) + chunkCount(4B LE)
  //       + N × { iv(12B) + 密文(含 16B tag) }
  static const int _fileChunkSize = 2 * 1024 * 1024; // 2MB

  /// 分块流式加密文件到容器（内存占用 = 单块级别）。
  ///
  /// [onProgress] 非 null 时经 SendPort 逐块上报 0.0~1.0 进度
  /// （独立 isolate 内运算，主线程零开销；null 时走免通信快速路径）。
  static Future<void> encryptFileToContainer(
    String srcPath,
    String destPath,
    String passphrase, {
    void Function(double progress)? onProgress,
  }) async {
    if (onProgress == null) {
      return Isolate.run(
        () => _encryptFileToContainerWorker([
          srcPath,
          destPath,
          passphrase,
          null,
        ]),
      );
    }
    final port = ReceivePort();
    await Isolate.spawn(_encryptFileToContainerWorker, [
      srcPath,
      destPath,
      passphrase,
      port.sendPort,
    ]);
    await for (final msg in port) {
      final list = msg as List;
      if (list[0] == 'progress') {
        onProgress(list[1] as double);
      } else if (list[0] == 'error') {
        throw Exception(list[1]);
      } else if (list[0] == 'done') {
        break;
      }
    }
    port.close();
  }

  static void _encryptFileToContainerWorker(List args) {
    final String srcPath = args[0];
    final String destPath = args[1];
    final String passphrase = args[2];
    final SendPort? port = args[3] as SendPort?;
    try {
      _encryptFileToContainerSync(
        srcPath,
        destPath,
        passphrase,
        onProgress: port == null ? null : (p) => port.send(['progress', p]),
      );
      port?.send(['done']);
    } catch (e) {
      if (port != null) {
        Isolate.exit(port, ['error', e.toString()]);
      }
      rethrow;
    }
  }

  static Future<void> _encryptFileToContainerSync(
    String srcPath,
    String destPath,
    String passphrase, {
    void Function(double progress)? onProgress,
  }) async {
    final salt = _randomBytes(_saltLen);
    final key = _deriveKey(passphrase, salt);
    final srcFile = File(srcPath);
    final total = await srcFile.length();
    final chunkSize = _fileChunkSize;
    final chunkCount = total == 0 ? 0 : (total + chunkSize - 1) ~/ chunkSize;

    final cipher = GCMBlockCipher(AESEngine());
    final sink = File(destPath).openWrite();
    var index = 0;
    var pending = BytesBuilder();
    var pendingLen = 0;
    try {
      final header = BytesBuilder();
      header.add(_magic);
      header.addByte(2);
      header.add(salt);
      header.add(_uint32LE(chunkSize));
      header.add(_uint32LE(chunkCount));
      sink.add(header.toBytes());

      await for (final raw in srcFile.openRead()) {
        pending.add(raw);
        pendingLen += raw.length;
        while (pendingLen >= chunkSize) {
          final taken = pending.takeBytes();
          final chunk = Uint8List.sublistView(taken, 0, chunkSize);
          _encryptChunk(sink, cipher, key, chunk, index);
          index++;
          if (onProgress != null && chunkCount > 0) {
            onProgress((index / chunkCount).clamp(0.0, 1.0));
          }
          pending = BytesBuilder();
          if (taken.length > chunkSize) {
            pending.add(Uint8List.sublistView(taken, chunkSize));
            pendingLen = taken.length - chunkSize;
          } else {
            pendingLen = 0;
          }
        }
      }
      if (pendingLen > 0) {
        _encryptChunk(sink, cipher, key, pending.takeBytes(), index);
        index++;
      }
      if (onProgress != null && chunkCount > 0) {
        onProgress(1.0);
      }
      if (index != chunkCount) {
        throw Exception("加密失败：加密过程中文件大小发生变化");
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  static void _encryptChunk(
    IOSink sink,
    GCMBlockCipher cipher,
    Uint8List key,
    Uint8List chunk,
    int index,
  ) {
    final iv = _randomBytes(_ivLen);
    cipher.init(
      true,
      AEADParameters(KeyParameter(key), 128, iv, _chunkAad(index)),
    );
    final out = Uint8List(chunk.length + 16);
    final n = cipher.processBytes(chunk, 0, chunk.length, out, 0);
    final n2 = cipher.doFinal(out, n);
    sink.add(iv);
    sink.add(Uint8List.sublistView(out, 0, n + n2));
  }

  /// 解密 v2 分块容器到文件（流式，内存占用 = 单块级别）。
  ///
  /// [onProgress] 语义同 [encryptFileToContainer]。
  static Future<void> decryptFileContainer(
    String srcPath,
    String destPath,
    String passphrase, {
    void Function(double progress)? onProgress,
  }) async {
    if (onProgress == null) {
      return Isolate.run(
        () =>
            _decryptFileContainerWorker([srcPath, destPath, passphrase, null]),
      );
    }
    final port = ReceivePort();
    await Isolate.spawn(_decryptFileContainerWorker, [
      srcPath,
      destPath,
      passphrase,
      port.sendPort,
    ]);
    await for (final msg in port) {
      final list = msg as List;
      if (list[0] == 'progress') {
        onProgress(list[1] as double);
      } else if (list[0] == 'error') {
        throw Exception(list[1]);
      } else if (list[0] == 'done') {
        break;
      }
    }
    port.close();
  }

  static void _decryptFileContainerWorker(List args) {
    final String srcPath = args[0];
    final String destPath = args[1];
    final String passphrase = args[2];
    final SendPort? port = args[3] as SendPort?;
    try {
      _decryptFileContainerSync(
        srcPath,
        destPath,
        passphrase,
        onProgress: port == null ? null : (p) => port.send(['progress', p]),
      );
      port?.send(['done']);
    } catch (e) {
      if (port != null) {
        Isolate.exit(port, ['error', e.toString()]);
      }
      rethrow;
    }
  }

  static Future<void> _decryptFileContainerSync(
    String srcPath,
    String destPath,
    String passphrase, {
    void Function(double progress)? onProgress,
  }) async {
    final headerLen = _magic.length + 1 + _saltLen + 8; // 5+1+16+4+4 = 30
    final src = File(srcPath);
    final total = await src.length();
    if (total <= headerLen) {
      throw Exception("解密失败：备份文件已损坏");
    }
    final raf = await src.open();
    final sink = File(destPath).openWrite();
    try {
      await raf.setPosition(0);
      final header = await raf.read(headerLen);
      if (header.length < headerLen) {
        throw Exception("解密失败：备份文件已损坏");
      }
      for (int i = 0; i < _magic.length; i++) {
        if (header[i] != _magic[i]) {
          throw Exception("解密失败：不是本应用生成的备份文件");
        }
      }
      if (header[_magic.length] != 2) {
        throw Exception("解密失败：不支持的备份版本");
      }
      final salt = Uint8List.sublistView(header, 6, 6 + _saltLen);
      final chunkSize = _readUint32LE(header, 6 + _saltLen);
      final chunkCount = _readUint32LE(header, 6 + _saltLen + 4);
      if (chunkSize <= 0 || chunkSize > (1 << 30)) {
        throw Exception("解密失败：备份文件已损坏");
      }
      final key = _deriveKey(passphrase, salt);
      final cipher = GCMBlockCipher(AESEngine());

      for (var i = 0; i < chunkCount; i++) {
        if (onProgress != null && chunkCount > 0 && i > 0) {
          onProgress((i / chunkCount).clamp(0.0, 1.0));
        }
        final iv = await raf.read(_ivLen);
        if (iv.length < _ivLen) {
          throw Exception("解密失败：备份文件不完整");
        }
        // 最后一块密文 = 剩余明文长度 + 16B tag，先探明长度
        final ctExpect = chunkSize + 16;
        final ct = await raf.read(ctExpect);
        if (ct.length < 16) {
          throw Exception("解密失败：备份文件不完整");
        }
        cipher.init(
          false,
          AEADParameters(
            KeyParameter(key),
            128,
            Uint8List.fromList(iv),
            _chunkAad(i),
          ),
        );
        try {
          final out = Uint8List(ct.length);
          final n = cipher.processBytes(
            Uint8List.fromList(ct),
            0,
            ct.length,
            out,
            0,
          );
          final n2 = cipher.doFinal(out, n);
          sink.add(Uint8List.sublistView(out, 0, n + n2));
        } on Exception {
          throw Exception("解密失败：加密口令错误或文件已损坏");
        }
      }
    } finally {
      await raf.close();
      await sink.flush();
      await sink.close();
    }
  }

  static Uint8List _chunkAad(int index) {
    return _uint32LE(index);
  }

  static Uint8List _uint32LE(int v) {
    final b = Uint8List(4);
    b[0] = v & 0xff;
    b[1] = (v >> 8) & 0xff;
    b[2] = (v >> 16) & 0xff;
    b[3] = (v >> 24) & 0xff;
    return b;
  }

  static int _readUint32LE(Uint8List b, int off) {
    return b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24);
  }
}
