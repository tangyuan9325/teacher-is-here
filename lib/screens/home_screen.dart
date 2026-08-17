import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/macaron_theme.dart';
import '../widgets/glass_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.flutter_application/native');

  // 状态
  String _selectedAppName = "未选择应用";
  String _selectedPackageName = "";
  int _lockMinutes = 25;
  List<Map<String, String>> _appList = [];
  List<Map<String, String>> _filteredAppList = [];
  bool _isServiceRunning = false;
  bool _isLocking = false;
  int _remainingSeconds = 0;
  bool _hasOverlayPermission = false;
  bool _hasAccessibilityPermission = false;
  bool _isBatteryOptimized = false;

  // 动画
  late AnimationController _gradientController;
  Timer? _countdownTimer;

  // 预设时长
  final List<int> _durationPresets = [5, 15, 25, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _checkAllPermissions();
    _checkServiceStatus();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // 轮询锁定状态和剩余时间
  void _startStatusPolling() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final locking = await platform.invokeMethod('isLocking');
        final remaining = await platform.invokeMethod('getLockRemainingSeconds');
        if (mounted) {
          setState(() {
            _isLocking = locking ?? false;
            _remainingSeconds = remaining ?? 0;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _checkAllPermissions() async {
    try {
      final overlay = await platform.invokeMethod('hasOverlayPermission');
      final accessibility = await platform.invokeMethod('hasAccessibilityPermission');
      final battery = await platform.invokeMethod('isIgnoringBatteryOptimizations');
      if (mounted) {
        setState(() {
          _hasOverlayPermission = overlay ?? false;
          _hasAccessibilityPermission = accessibility ?? false;
          _isBatteryOptimized = battery ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkServiceStatus() async {
    try {
      final running = await platform.invokeMethod('isServiceRunning');
      if (mounted) setState(() => _isServiceRunning = running ?? false);
    } catch (_) {}
  }

  Future<void> _getAppList() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getAppList');
      final list = result.map((e) => Map<String, String>.from(e)).toList();
      if (mounted) {
        setState(() {
          _appList = list;
          _filteredAppList = list;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("获取应用列表失败: $e")),
        );
      }
    }
  }

  Future<void> _startFloatingWindow() async {
    if (_selectedPackageName.isEmpty) {
      _showSnackBar("请先选择一个要专注的应用", MacaronColors.coral);
      return;
    }
    if (!_hasOverlayPermission) {
      await platform.invokeMethod('requestOverlayPermission');
      _showSnackBar("请在设置中授予悬浮窗权限", MacaronColors.peach);
      return;
    }
    if (!_hasAccessibilityPermission) {
      await platform.invokeMethod('requestAccessibilityPermission');
      _showSnackBar("请在设置中开启无障碍服务（用于锁定应用）", MacaronColors.lavender);
      return;
    }

    try {
      await platform.invokeMethod('startFloatingWindow', {
        'packageName': _selectedPackageName,
        'minutes': _lockMinutes,
      });
      setState(() => _isServiceRunning = true);
      _showSnackBar("悬浮窗已启动！点击\"老师来了\"开始专注", MacaronColors.mint);
    } catch (e) {
      _showSnackBar("启动失败: $e", MacaronColors.coral);
    }
  }

  Future<void> _stopFloatingWindow() async {
    try {
      await platform.invokeMethod('stopFloatingWindow');
      setState(() {
        _isServiceRunning = false;
        _isLocking = false;
      });
      _showSnackBar("已停止悬浮窗", MacaronColors.sky);
    } catch (e) {
      _showSnackBar("停止失败: $e", MacaronColors.coral);
    }
  }

  void _showSnackBar(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFFFFE4F0),
                    const Color(0xFFE4F0FF),
                    _gradientController.value,
                  )!,
                  Color.lerp(
                    const Color(0xFFF0FFE4),
                    const Color(0xFFFFF0E4),
                    _gradientController.value,
                  )!,
                  Color.lerp(
                    const Color(0xFFF5E4FF),
                    const Color(0xFFE4FFF5),
                    _gradientController.value,
                  )!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildPermissionRow(),
                const SizedBox(height: 24),
                if (_isLocking) _buildLockingCard(),
                if (_isLocking) const SizedBox(height: 20),
                _buildAppSelectionCard(),
                const SizedBox(height: 16),
                _buildDurationCard(),
                const SizedBox(height: 28),
                _buildActionButton(),
                const SizedBox(height: 24),
                _buildTipsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MacaronColors.pink, MacaronColors.peach],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: MacaronColors.pink.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text("👩‍🏫", style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "老师来了",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: MacaronColors.textPrimary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "防摸鱼专注神器 · 锁定你的注意力",
          style: TextStyle(
            fontSize: 14,
            color: MacaronColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PermissionBadge(
          label: "悬浮窗",
          granted: _hasOverlayPermission,
          onTap: () async {
            await platform.invokeMethod('requestOverlayPermission');
            Future.delayed(const Duration(seconds: 2), _checkAllPermissions);
          },
        ),
        const SizedBox(width: 8),
        PermissionBadge(
          label: "无障碍",
          granted: _hasAccessibilityPermission,
          onTap: () async {
            await platform.invokeMethod('requestAccessibilityPermission');
            Future.delayed(const Duration(seconds: 2), _checkAllPermissions);
          },
        ),
        const SizedBox(width: 8),
        PermissionBadge(
          label: "电池",
          granted: _isBatteryOptimized,
          onTap: () async {
            await platform.invokeMethod('requestBatteryOptimization');
            Future.delayed(const Duration(seconds: 2), _checkAllPermissions);
          },
        ),
      ],
    );
  }

  Widget _buildLockingCard() {
    return GlassContainer(
      gradientColors: [
        MacaronColors.mint.withValues(alpha: 0.5),
        MacaronColors.sky.withValues(alpha: 0.5),
      ],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: MacaronColors.darkMint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "专注锁定中",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MacaronColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatDuration(_remainingSeconds),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: MacaronColors.textPrimary,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "正在锁定：$_selectedAppName",
            style: const TextStyle(
              fontSize: 14,
              color: MacaronColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSelectionCard() {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStepBadge("1", MacaronColors.pink),
              const SizedBox(width: 10),
              const Text(
                "选择要专注的应用",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MacaronColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _showAppPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MacaronColors.lavender, MacaronColors.pink],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.apps, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedAppName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: MacaronColors.textPrimary,
                          ),
                        ),
                        if (_selectedPackageName.isNotEmpty)
                          Text(
                            _selectedPackageName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: MacaronColors.textLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: MacaronColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationCard() {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStepBadge("2", MacaronColors.mint),
              const SizedBox(width: 10),
              const Text(
                "专注时长",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MacaronColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durationPresets.map((minutes) {
              final selected = _lockMinutes == minutes;
              return GestureDetector(
                onTap: () => setState(() => _lockMinutes = minutes),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [MacaronColors.mint, MacaronColors.sky],
                          )
                        : null,
                    color: selected ? null : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    "$minutes 分钟",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : MacaronColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: MacaronColors.mint,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.5),
                    thumbColor: Colors.white,
                    overlayColor: MacaronColors.mint.withValues(alpha: 0.3),
                    valueIndicatorColor: MacaronColors.mint,
                    valueIndicatorTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _lockMinutes.toDouble(),
                    min: 1,
                    max: 120,
                    divisions: 119,
                    label: "$_lockMinutes 分钟",
                    onChanged: (val) => setState(() => _lockMinutes = val.toInt()),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MacaronColors.mint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$_lockMinutes 分",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: MacaronColors.darkMint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isServiceRunning || _isLocking) {
      return Center(
        child: MacaronButton(
          text: _isLocking ? "专注中（时间到自动解锁）" : "停止悬浮窗",
          onPressed: _isLocking ? null : _stopFloatingWindow,
          gradientColors: MacaronColors.stopButtonGradient,
          icon: _isLocking ? Icons.lock : Icons.stop,
        ),
      );
    }
    return Center(
      child: MacaronButton(
        text: "启动悬浮窗",
        onPressed: _startFloatingWindow,
        gradientColors: MacaronColors.startButtonGradient,
        icon: Icons.play_arrow,
      ),
    );
  }

  Widget _buildTipsCard() {
    return GlassContainer(
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_circle, color: MacaronColors.lemon, size: 20),
              SizedBox(width: 8),
              Text(
                "使用说明",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: MacaronColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _TipRow(text: "授予悬浮窗、无障碍、电池优化三项权限"),
          _TipRow(text: "选择要专注的应用并设置时长"),
          _TipRow(text: "点击启动，屏幕边缘会出现\"老师来了\"悬浮球"),
          _TipRow(text: "在任意界面点击悬浮球，立即跳转并锁定目标应用"),
          _TipRow(text: "锁定期间无法退出到桌面或其他应用，时间到自动解锁"),
        ],
      ),
    );
  }

  Widget _buildStepBadge(String num, Color color) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          num,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showAppPicker() {
    _getAppList();
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    const Color(0xFFF0F4FF).withValues(alpha: 0.95),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "选择应用",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: MacaronColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: "搜索应用...",
                          hintStyle: TextStyle(color: MacaronColors.textLight),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: MacaronColors.textSecondary),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            searchQuery = value;
                            _filteredAppList = _appList
                                .where((app) =>
                                    app["name"]!.toLowerCase().contains(searchQuery.toLowerCase()) ||
                                    app["package"]!.toLowerCase().contains(searchQuery.toLowerCase()))
                                .toList();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _filteredAppList.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(MacaronColors.mint),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "正在加载应用列表...",
                                  style: TextStyle(color: MacaronColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredAppList.length,
                            itemBuilder: (ctx, index) {
                              final app = _filteredAppList[index];
                              final isSelected = app["package"] == _selectedPackageName;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedAppName = app["name"]!;
                                      _selectedPackageName = app["package"]!;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? MacaronColors.mint.withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? MacaronColors.mint
                                            : Colors.white.withValues(alpha: 0.6),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                MacaronColors.pink.withValues(alpha: 0.6),
                                                MacaronColors.lavender.withValues(alpha: 0.6),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              app["name"]!.characters.first,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                app["name"]!,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: MacaronColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                app["package"]!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: MacaronColors.textLight,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: MacaronColors.darkMint,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TipRow extends StatelessWidget {
  final String text;
  const _TipRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(color: MacaronColors.pink, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: MacaronColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
