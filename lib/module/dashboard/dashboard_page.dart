import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 运行概览页（青龙 2.x 新增 /api/dashboard 接口）
/// 展示：任务统计、今日运行情况、面板系统资源
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool loading = true;
  Map<String, dynamic>? overview;
  Map<String, dynamic>? system;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (mounted && loading) {
      setState(() {});
    }
    var res1 = await SingleAccountPageState.ofApi(context).dashboardOverview();
    var res2 = await SingleAccountPageState.ofApi(context).dashboardSystem();

    if (!mounted) return;

    if (res1.success) {
      try {
        overview = jsonDecode(res1.bean ?? "{}");
      } catch (e) {
        overview = null;
      }
    } else {
      res1.message?.toast();
    }
    if (res2.success) {
      try {
        system = jsonDecode(res2.bean ?? "{}");
      } catch (e) {
        system = null;
      }
    } else {
      res2.message?.toast();
    }
    loading = false;
    if (mounted) {
      setState(() {});
    }
  }

  String _formatBytes(dynamic v) {
    double? b = double.tryParse(v.toString());
    if (b == null || b <= 0) return "-";
    if (b > 1024 * 1024 * 1024) {
      return "${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
    }
    return "${(b / 1024 / 1024).toStringAsFixed(1)} MB";
  }

  String _formatUptime(dynamic v) {
    int? sec = int.tryParse(v.toString());
    if (sec == null || sec <= 0) return "-";
    int d = sec ~/ 86400;
    int h = (sec % 86400) ~/ 3600;
    int m = (sec % 3600) ~/ 60;
    if (d > 0) return "$d天$h小时$m分";
    if (h > 0) return "$h小时$m分";
    return "$m分钟";
  }

  String _formatTime(dynamic v) {
    int? ms = int.tryParse(v.toString());
    if (ms == null || ms <= 0) return "-";
    if (ms > 1000) {
      return "${(ms / 1000).toStringAsFixed(1)} 秒";
    }
    return "$ms 毫秒";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QlAppBar(
        title: "运行概览",
      ),
      body: loading
          ? const Center(child: LoadingWidget())
          : RefreshIndicator(
              color: Theme.of(context).primaryColor,
              onRefresh: () async {
                await loadData();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                children: [
                  _buildOverview(),
                  const SizedBox(height: 15),
                  _buildSystem(),
                ],
              ),
            ),
    );
  }

  Map<String, dynamic> get _stats =>
      (overview?["stats"] as Map<String, dynamic>?) ?? {};

  Widget _buildOverview() {
    var theme = ref.watch(themeProvider).themeColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: theme.settingBgColor(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "任务统计",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.titleColor(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _cell("总任务", overview?["total"] ?? "-"),
              _cell("已启用", overview?["enabled"] ?? "-"),
              _cell("已禁用", overview?["disabled"] ?? "-"),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "今日运行",
            style: TextStyle(
              fontSize: 14,
              color: theme.descColor(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _cell("运行次数", _stats["total_runs"] ?? 0),
              _cell("成功", _stats["total_success"] ?? 0, color: const Color(0xff27AE60)),
              _cell("失败", _stats["total_fail"] ?? 0, color: const Color(0xffFB5858)),
              _cell("总耗时", _formatTime(_stats["total_time"])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystem() {
    var theme = ref.watch(themeProvider).themeColor;
    List loadAvg = (system?["loadAvg"] as List?) ?? [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: theme.settingBgColor(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "系统资源",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.titleColor(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _cell("内存使用率", "${system?["memUsagePercent"] ?? "-"}%"),
              _cell("内存总量", _formatBytes(system?["memTotal"])),
              _cell("剩余内存", _formatBytes(system?["memFree"])),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _cell("CPU 核数", system?["cpus"] ?? "-"),
              _cell("运行时长", _formatUptime(system?["uptime"])),
              _cell("平台", system?["platform"] ?? "-"),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "负载均值：${loadAvg.isEmpty ? "-" : loadAvg.join(" / ")}",
            style: TextStyle(
              fontSize: 13,
              color: theme.descColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String title, dynamic value, {Color? color}) {
    var theme = ref.watch(themeProvider).themeColor;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: theme.descColor(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value?.toString() ?? "-",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color ?? theme.titleColor(),
            ),
          ),
        ],
      ),
    );
  }
}
