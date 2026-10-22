import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 数据备份页（青龙 2.x /api/system/data/export、/api/system/data/import）
/// 导出：下载 zip 并通过系统分享保存
/// 导入：选择备份 zip 上传恢复（支持 crons/envs/scripts/configs 等）
class DataBackupPage extends ConsumerStatefulWidget {
  const DataBackupPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends ConsumerState<DataBackupPage> {
  bool exporting = false;

  Future<void> exportData() async {
    if (exporting) return;
    setState(() {
      exporting = true;
    });
    EasyLoading.show(status: "导出中");
    var response = await SingleAccountPageState.ofApi(context).exportData();
    EasyLoading.dismiss();
    try {
      if (response == null) {
        "导出失败".toast();
        return;
      }
      List<int> bytes;
      if (response.data is List<int>) {
        bytes = (response.data as List<int>).toList();
      } else if (response.data is String) {
        bytes = (response.data as String).codeUnits;
      } else {
        bytes = [];
      }
      if (bytes.isEmpty) {
        "导出数据为空".toast();
        return;
      }
      Directory dir = await getTemporaryDirectory();
      String path =
          "${dir.path}/qinglong_backup_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.zip";
      File file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareFiles([path], subject: "青龙面板数据备份");
    } catch (e) {
      e.toString().toast();
    } finally {
      if (mounted) {
        setState(() {
          exporting = false;
        });
      }
    }
  }

  Future<void> importData() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.single.path == null) {
      return;
    }
    String filePath = result.files.single.path!;
    if (!filePath.toLowerCase().endsWith(".zip")) {
      "请选择导出的 zip 备份文件".toast();
      return;
    }
    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("导入数据"),
        content: const Text("导入会覆盖面板中对应的任务、环境变量等数据，确认继续？"),
        actions: [
          CupertinoDialogAction(
            child: const Text(
              "取消",
              style: TextStyle(color: Color(0xff999999)),
            ),
            onPressed: () => Navigator.of(context1).pop(),
          ),
          CupertinoDialogAction(
            child: Text(
              "确认导入",
              style: TextStyle(color: ref.watch(themeProvider).primaryColor),
            ),
            onPressed: () async {
              Navigator.of(context1).pop();
              EasyLoading.show(status: "导入中");
              var res = await SingleAccountPageState.ofApi(context).importData(filePath);
              EasyLoading.dismiss();
              if (res.success) {
                "导入成功".toast();
              } else {
                (res.message ?? "导入失败").toast();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = ref.watch(themeProvider).themeColor;
    return Scaffold(
      appBar: QlAppBar(
        title: "数据备份",
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          const SizedBox(height: 10),
          CupertinoButton(
            color: ref.watch(themeProvider).primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: exporting ? null : exportData,
            child: const Text(
              "导出备份数据",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            color: const Color(0xff888888),
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: importData,
            child: const Text(
              "从备份恢复",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "说明：\n\n· 导出的 zip 包含定时任务、环境变量、脚本、配置文件、订阅等数据，可通过系统分享保存到文件 App 或 iCloud。\n\n· 恢复时请选择本面板（或其他青龙面板）导出的备份文件。\n\n· 恢复操作会覆盖面板中对应的现有数据，请谨慎操作。",
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: theme.descColor(),
            ),
          ),
        ],
      ),
    );
  }
}
