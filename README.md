# 👩‍🏫 老师来了 (Teacher Is Here)

> 防摸鱼专注神器 —— 老师来了，还敢摸鱼？

一款基于 Flutter 的 Android 专注应用，通过悬浮窗一键锁定目标应用，阻止你在专注期间退出到桌面或切换到其他应用。

## ✨ 核心功能

- **悬浮窗控制**：启动后在屏幕边缘显示可拖拽的"老师来了"悬浮球，圆角马卡龙配色
- **应用选择**：从已安装应用中选择要专注的目标应用，支持搜索
- **定时锁定**：支持 1-120 分钟自定义专注时长，提供常用预设
- **强制锁定**：锁定期间使用无障碍服务 + 看门狗双重机制，任何退出尝试都会被立即拉回
- **自动解锁**：专注时间结束后自动解锁，无需手动操作
- **马卡龙 UI**：整体界面采用马卡龙 pastel 色系，搭配 Liquid Glass 毛玻璃效果

## 🎨 设计特色

- **马卡龙色系**：草莓粉、蜜桃橙、薄荷绿、薰衣草紫、天空蓝、柠檬黄
- **Liquid Glass 效果**：使用 `BackdropFilter` 实现真实毛玻璃模糊
- **动态渐变背景**：背景色缓慢流动变化
- **圆角悬浮窗**：24dp 圆角 + 渐变 + 白色描边

## 🔧 技术实现

### 架构
- **Flutter**：UI 层（主界面、设置、应用选择）
- **Kotlin 原生**：悬浮窗服务、无障碍锁定服务
- **MethodChannel**：Flutter 与原生层通信

### 锁定机制（三重防护）
1. **无障碍事件监听**：`TYPE_WINDOW_STATE_CHANGED` 实时检测窗口切换
2. **看门狗轮询**：每 500ms 检查前台应用，作为事件丢失的兜底
3. **冷却防循环**：300ms 冷却时间避免无限重启循环
4. **震动反馈**：检测到退出尝试时震动提醒

### 权限要求
- `SYSTEM_ALERT_WINDOW`：悬浮窗权限
- 无障碍服务：应用锁定（需在系统设置中手动开启）
- `WAKE_LOCK`：保持屏幕常亮
- `QUERY_ALL_PACKAGES`：获取已安装应用列表
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`：后台保活

## 📦 构建

```bash
# 安装依赖
flutter pub get

# 构建 Release APK
flutter build apk --release

# 构建 Debug APK（快速测试）
flutter build apk --debug
```

APK 输出路径：`build/app/outputs/flutter-apk/app-release.apk`

## 📱 使用流程

1. 打开应用，授予悬浮窗、无障碍、电池优化三项权限
2. 选择要专注的应用（如学习类、阅读类应用）
3. 设置专注时长
4. 点击"启动悬浮窗"
5. 在任意界面点击"老师来了"悬浮球
6. 自动跳转到目标应用并开始锁定
7. 时间到自动解锁

## 📁 项目结构

```
lib/
├── main.dart                    # 应用入口
├── theme/
│   └── macaron_theme.dart       # 马卡龙主题配色
├── widgets/
│   └── glass_widgets.dart       # Liquid Glass 组件
└── screens/
    └── home_screen.dart         # 主界面

android/app/src/main/
├── kotlin/com/example/flutter_application/
│   ├── MainActivity.kt          # 主 Activity + MethodChannel
│   ├── FloatingWindowService.kt # 悬浮窗服务
│   └── LockAccessibilityService.kt # 无障碍锁定服务
├── res/
│   ├── layout/floating_window.xml   # 悬浮窗布局
│   ├── drawable/floating_window_bg.xml  # 悬浮窗背景
│   └── xml/accessibility_service_config.xml
└── AndroidManifest.xml
```

## ⚠️ 注意事项

- 本应用仅支持 **Android** 平台（iOS 沙盒机制不支持悬浮窗和应用锁定）
- 无障碍服务需用户在系统设置中手动开启，应用会引导跳转
- 部分国产 ROM（小米、华为、OPPO/vivo）可能需要额外开启后台运行权限
- 锁定机制无法 100% 阻止系统级操作（如重启、关机），但可有效阻止常规退出

## 📄 License

[MIT License](LICENSE) © 2026 TangYuan
