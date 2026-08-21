import QtQuick
import QtQuick.Controls

Menu {
    id: root

    signal presetSelected(string badge, string label, string prompt)

    background: Rectangle {
        implicitWidth: 260
        implicitHeight: 200
        radius: 10
        color: Theme.bgDialog
        border.color: Theme.borderLight
        border.width: 1
    }

    MenuItem {
        text: AppManager.isThai ? "💻 วิเคราะห์โค้ดและหาบั๊ก (Debug Code)" : "💻 Debug & Fix Code"
        font.family: Theme.fontFamily
        onTriggered: root.presetSelected(
            "D",
            AppManager.isThai ? "วิเคราะห์โค้ด (Debug)" : "Debug Code",
            AppManager.isThai ? "กรุณาวิเคราะห์โค้ดนี้ อธิบายสาเหตุของข้อผิดพลาด (Bugs) และให้โค้ดเวอร์ชันที่แก้ไขถูกต้องพร้อมคำอธิบายอย่างชัดเจน"
                              : "Please analyze this code, explain any bugs/issues, and provide the corrected code with concise explanations."
        )
    }

    MenuItem {
        text: AppManager.isThai ? "🇬🇧 ตรวจและแก้ไวยากรณ์ (Grammar Fix)" : "🇬🇧 Grammar & Tone Fix"
        font.family: Theme.fontFamily
        onTriggered: root.presetSelected(
            "G",
            AppManager.isThai ? "ตรวจแกรมม่า (Grammar)" : "Grammar Fix",
            AppManager.isThai ? "กรุณาตรวจทานและแก้ไขข้อความนี้ให้ถูกต้องตามหลักไวยากรณ์ เป็นธรรมชาติ และสละสลวย"
                              : "Please proofread and correct this text for grammar, clarity, and natural professional tone."
        )
    }

    MenuItem {
        text: AppManager.isThai ? "📊 แปลงเป็นตาราง Markdown (Format Table)" : "📊 Convert to Markdown Table"
        font.family: Theme.fontFamily
        onTriggered: root.presetSelected(
            "T",
            AppManager.isThai ? "แปลงเป็นตาราง (Table)" : "Format Table",
            AppManager.isThai ? "กรุณาดึงข้อมูลสำคัญทั้งหมดออกมาจัดระเบียบในรูปแบบตาราง Markdown ให้ครบถ้วนและอ่านง่าย"
                              : "Please extract all key structured data and format it into a clean Markdown table."
        )
    }

    MenuItem {
        text: AppManager.isThai ? "💡 อธิบายแบบเข้าใจง่าย (Explain Simply)" : "💡 Explain Like I'm 5 (ELI5)"
        font.family: Theme.fontFamily
        onTriggered: root.presetSelected(
            "E",
            AppManager.isThai ? "อธิบายง่ายๆ (ELI5)" : "Explain Simply",
            AppManager.isThai ? "กรุณาอธิบายหัวข้อหรือเนื้อหานี้ให้เข้าใจง่ายที่สุด พร้อมยกตัวอย่างประกอบที่เห็นภาพชัดเจน"
                              : "Please explain this concept in the simplest possible terms with clear, relatable analogies."
        )
    }

    MenuItem {
        text: AppManager.isThai ? "🌐 แปลเป็นภาษาอังกฤษ (Translate to EN)" : "🌐 Translate to Thai"
        font.family: Theme.fontFamily
        onTriggered: root.presetSelected(
            "TR",
            AppManager.isThai ? "แปลเป็นอังกฤษ (To EN)" : "Translate to Thai",
            AppManager.isThai ? "กรุณาแปลข้อความทั้งหมดนี้เป็นภาษาอังกฤษอย่างถูกต้อง สละสลวย และเป็นธรรมชาติ"
                              : "Please translate all content accurately and naturally into Thai."
        )
    }
}
