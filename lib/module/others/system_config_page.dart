import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 面板配置页（青龙 2.x /api/system/config 接口）
/// 支持修改：面板标题、时区、任务并发数
class SystemConfigPage extends ConsumerStatefulWidget {
  const SystemConfigPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SystemConfigPage> createState() => _SystemConfigPageState();
}

class _SystemConfigPageState extends ConsumerState<SystemConfigPage> {
  bool loading = true;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController timezoneController = TextEditingController();
  final TextEditingController concurrencyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    titleController.dispose();
    timezoneController.dispose();
    concurrencyController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    var res = await SingleAccountPageState.ofApi(context).systemConfig();
    if (!mounted) return;
    if (res.success) {
      try {
        Map<String, dynamic> json = jsonDecode(res.bean ?? "{}");
        Map<String, dynamic> info = (json["info"] as Map<String, dynamic>?) ?? {};
        titleController.text = info["panelTitle"]?.toString() ?? "";
        timezoneController.text = info["timezone"]?.toString() ?? "Asia/Shanghai";
        concurrencyController.text =
            info["cronConcurrency"] == null ? "" : info["cronConcurrency"].toString();
      } catch (e) {
        "配置解析失败".toast();
      }
    } else {
      res.message?.toast();
    }
    loading = false;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = ref.watch(themeProvider).themeColor;
    return Scaffold(
      appBar: QlAppBar(
        title: "面板配置",
      ),
      body: loading
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _item(
                      "面板标题",
                      titleController,
                      "请输入面板标题",
                      () async {
                        EasyLoading.show(status: "提交中");
                        var res = await SingleAccountPageState.ofApi(context)
                            .updatePanelTitle(titleController.text.trim());
                        EasyLoading.dismiss();
                        _handleResult(res);
                      },
                    ),
                    _item(
                      "时区",
                      timezoneController,
                      "例如：Asia/Shanghai",
                      () async {
                        EasyLoading.show(status: "提交中");
                        var res = await SingleAccountPageState.ofApi(context)
                            .updateTimezone(timezoneController.text.trim());
                        EasyLoading.dismiss();
                        _handleResult(res);
                      },
                    ),
                    _item(
                      "任务并发数（0 为无限制）",
                      concurrencyController,
                      "请输入数字",
                      () async {
                        int? n = int.tryParse(concurrencyController.text.trim());
                        if (n == null || n < 0) {
                          "请输入正确的数字".toast();
                          return;
                        }
                        EasyLoading.show(status: "提交中");
                        var res = await SingleAccountPageState.ofApi(context)
                            .updateCronConcurrency(n);
                        EasyLoading.dismiss();
                        _handleResult(res);
                      },
                      inputType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _handleResult(dynamic res) {
    if (res.success) {
      "设置成功".toast();
    } else {
      (res.message ?? "设置失败").toast();
    }
  }

  Widget _item(
    String label,
    TextEditingController controller,
    String hint,
    Future<void> Function() onSave, {
    TextInputType? inputType,
  }) {
    var theme = ref.watch(themeProvider).themeColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: theme.titleColor(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: inputType,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            CupertinoButton(
              color: ref.watch(themeProvider).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              minSize: 30,
              onPressed: onSave,
              child: const Text(
                "保存",
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
