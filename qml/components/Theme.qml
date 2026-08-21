import QtQuick
import QtQuick.Controls

pragma Singleton

QtObject {
    // Theme Mode: "light" | "dark" | "system"
    property string currentTheme: "light"
    property bool isDark: currentTheme === "dark"

    // Colors - Backgrounds
    readonly property color bgMain: isDark ? "#18191c" : "#ffffff"
    readonly property color bgDialog: isDark ? "#202227" : "#ffffff"
    readonly property color bgCard: isDark ? "#282a30" : "#f8fafc"
    readonly property color bgCardHover: isDark ? "#32353d" : "#f1f5f9"
    readonly property color bgInput: isDark ? "#1b1c20" : "#ffffff"
    readonly property color bgPill: isDark ? "#23252b" : "#ffffff"

    // Colors - Text
    readonly property color textPrimary: isDark ? "#f3f4f6" : "#1e293b"
    readonly property color textSecondary: isDark ? "#9ca3af" : "#64748b"
    readonly property color textMuted: isDark ? "#6b7280" : "#94a3b8"

    // Colors - Borders
    readonly property color borderLight: isDark ? "#14ffffff" : "#14000000"
    readonly property color borderFocus: isDark ? "#3b82f6" : "#2563eb"

    // Accent Colors
    readonly property color primary: "#1a73e8"
    readonly property color primaryHover: "#1557b0"
    readonly property color primaryText: "#ffffff"

    readonly property color danger: "#ef4444"
    readonly property color dangerHover: "#dc2626"
    readonly property color success: "#10b981"
    readonly property color warning: "#f59e0b"

    // Shadow
    readonly property color shadowColor: isDark ? "#80000000" : "#1f000000"

    // Typography
    readonly property string fontFamily: "Segoe UI, 'Noto Sans Thai', sans-serif"
}
