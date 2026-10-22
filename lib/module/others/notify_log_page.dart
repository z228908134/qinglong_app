import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 通知日志页（青龙 2.x /api/system/notify-log 接口）
class NotifyLogPage extends ConsumerStatefulWidget {
  const NotifyLogPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NotifyLogPage> createState() => _NotifyLogPageState();
}

class _NotifyLogPageState extends ConsumerState<NotifyLogPage> {
  bool loading = true;
  List<Map<String, dynamic>> logs = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    var res = await SingleAccountPageState.ofApi(context).notifyLog();
    if (!mounted) return;
    if (res.success) {
      try {
        var data = jsonDecode(res.bean ?? "[]");
        if (data is List) {
          logs = data.map((e) => Map<String, dynamic>.from(e)).toList();
        } else {
          logs = [];
        }
      } catch (e) {
        logs = [];
      }
    } else {
      res.message?.toast();
    }
    loading = false;
    if (mounted) {
      setState(() {});
    }
  }

  String _formatTime(dynamic ts) {
    int? ms = int.tryParse(ts.toString());
    if (ms == null || ms <= 0) return "-";
    DateTime t = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} "
        "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    var theme = ref.watch(themeProvider).themeColor;
    return Scaffold(
      appBar: QlAppBar(
        title: "通知日志",
      ),
      body: loading
          ? const Center(child: LoadingWidget())
          : logs.isEmpty
              ? Center(
                  child: Text(
                    "暂无通知记录",
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
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 15),
                    itemBuilder: (context, index) {
                      var log = logs[index];
                      bool success = log["status"] == 0;
                      String source = (log["source"] ?? "").toString();
                      String sourceText = source == "script"
                          ? (log["scriptName"] ?? "脚本").toString()
                          : (log["notifyType"] ?? "系统").toString();
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                        title: Text(
                          log["title"]?.toString() ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: theme.titleColor(),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log["content"]?.toString() ?? "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.descColor(),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$sourceText · ${_formatTime(log["timestamp"])}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.descColor(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Icon(
                          success ? CupertinoIcons.checkmark_circle : CupertinoIcons.xmark_circle,
                          size: 18,
                          color: success ? const Color(0xff27AE60) : const Color(0xffFB5858),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
