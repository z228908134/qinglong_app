import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 脚本历史版本页（青龙 2.x 新增 /api/scripts/history 接口）
/// 支持查看历史内容、恢复到历史版本
class ScriptHistoryPage extends ConsumerStatefulWidget {
  final String filename;
  final String? path;

  const ScriptHistoryPage({
    Key? key,
    required this.filename,
    this.path,
  }) : super(key: key);

  @override
  ConsumerState<ScriptHistoryPage> createState() => _ScriptHistoryPageState();
}

class _ScriptHistoryPageState extends ConsumerState<ScriptHistoryPage> {
  bool loading = true;
  List<Map<String, dynamic>> versions = [];
  String currentHash = "";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    var res = await SingleAccountPageState.ofApi(context)
        .scriptHistory(widget.filename, widget.path);
    if (!mounted) return;
    if (res.success) {
      try {
        Map<String, dynamic> json = jsonDecode(res.bean ?? "{}");
        versions = (json["versions"] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        currentHash = json["currentHash"]?.toString() ?? "";
      } catch (e) {
        versions = [];
      }
    } else {
      res.message?.toast();
    }
    loading = false;
    if (mounted) {
      setState(() {});
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return "-";
    try {
      DateTime t = DateTime.parse(iso).toLocal();
      return "${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} "
          "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return iso;
    }
  }

  String _formatSize(dynamic size) {
    int? b = int.tryParse(size.toString());
    if (b == null) return "-";
    if (b > 1024) return "${(b / 1024).toStringAsFixed(1)} KB";
    return "$b B";
  }

  void _viewDetail(Map<String, dynamic> version) async {
    EasyLoading.show(status: "加载中");
    var res = await SingleAccountPageState.ofApi(context)
        .scriptHistoryDetail(widget.filename, widget.path, version["id"].toString());
    EasyLoading.dismiss();
    if (!res.success) {
      (res.message ?? "获取历史内容失败").toast();
      return;
    }
    String content = "";
    try {
      Map<String, dynamic> json = jsonDecode(res.bean ?? "{}");
      var v = json["version"];
      if (v is Map) {
        content = v["content"]?.toString() ?? "";
      }
    } catch (e) {
      content = "";
    }
    if (!mounted) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => _HistoryContentView(content: content),
      ),
    );
  }

  void _restore(Map<String, dynamic> version) {
    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("恢复历史版本"),
        content: Text("确认将脚本恢复到 ${_formatTime(version["createdAt"]?.toString())} 的版本吗？当前内容将自动备份。"),
        actions: [
          CupertinoDialogAction(
            child: const Text(
              "取消",
              style: TextStyle(color: Color(0xff999999)),
            ),
            onPressed: () {
              Navigator.of(context1).pop();
            },
          ),
          CupertinoDialogAction(
            child: Text(
              "恢复",
              style: TextStyle(
                color: ref.watch(themeProvider).primaryColor,
              ),
            ),
            onPressed: () async {
              Navigator.of(context1).pop();
              if (currentHash.isEmpty) {
                "当前文件状态未知，请刷新后重试".toast();
                return;
              }
              EasyLoading.show(status: "恢复中");
              var res = await SingleAccountPageState.ofApi(context).restoreScriptHistory(
                    widget.filename,
                    widget.path,
                    version["id"].toString(),
                    currentHash,
                  );
              EasyLoading.dismiss();
              if (res.success) {
                "恢复成功".toast();
                await loadData();
              } else {
                (res.message ?? "恢复失败").toast();
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
        title: "历史版本",
      ),
      body: loading
          ? const Center(child: LoadingWidget())
          : versions.isEmpty
              ? Center(
                  child: Text(
                    "暂无历史版本\n（保存/修改脚本时自动生成）",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.descColor(),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: Theme.of(context).primaryColor,
                  onRefresh: () async {
                    await loadData();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: versions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 15),
                    itemBuilder: (context, index) {
                      var version = versions[index];
                      bool identical = version["identical"] == true;
                      return ListTile(
                        onTap: () {
                          _viewDetail(version);
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                        title: Text(
                          _formatTime(version["createdAt"]?.toString()),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: theme.titleColor(),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "${_formatSize(version["size"])}  ·  ${(version["source"] ?? "-").toString()}  ·  hash ${(version["hash"] ?? "").toString().substring(0, (version["hash"] ?? "------").toString().length >= 8 ? 8 : 6)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.descColor(),
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (identical)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.descColor().withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "当前内容",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.descColor(),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            CupertinoButton(
                              color: Colors.transparent,
                              padding: EdgeInsets.zero,
                              minSize: 30,
                              onPressed: () {
                                _restore(version);
                              },
                              child: Text(
                                "恢复",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ref.watch(themeProvider).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _HistoryContentView extends ConsumerWidget {
  final String content;

  const _HistoryContentView({required this.content});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var theme = ref.watch(themeProvider).themeColor;
    return Scaffold(
      appBar: QlAppBar(
        title: "版本内容",
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () {
              showCupertinoDialog(
                context: context,
                useRootNavigator: false,
                builder: (context1) => CupertinoAlertDialog(
                  title: const Text("复制内容"),
                  content: const Text("将历史版本内容复制到剪贴板？"),
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
                        "复制",
                        style: TextStyle(color: ref.watch(themeProvider).primaryColor),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: content));
                        Navigator.of(context1).pop();
                        "已复制".toast();
                      },
                    ),
                  ],
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Icon(CupertinoIcons.doc_on_doc, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: SelectableText(
          content.isEmpty ? "（内容为空）" : content,
          style: TextStyle(
            fontSize: 12,
            fontFamily: "monospace",
            color: theme.titleColor(),
          ),
        ),
      ),
    );
  }
}
