# Gemini Floating Toolbar

<div align="center">

**โปรแกรมผู้ช่วย Google Gemini บน Windows พร้อมแถบเมนูลอย แคปหน้าจอถาม AI และคีย์ลัดครอบข้อความถามด่วน**

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)](https://github.com/phwyverysad/Gemini-Floating-Toolbar)
[![Language](https://img.shields.io/badge/Language-C%2B%2B20%20%7C%20Qt6%20%7C%20QML-00599C?style=flat-square&logo=cplusplus&logoColor=white)](https://en.cppreference.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
[![Download](https://img.shields.io/badge/Download-Latest%20Release-brightgreen?style=flat-square)](https://github.com/phwyverysad/Gemini-Floating-Toolbar/releases)

</div>

---

## ✨ ฟีเจอร์หลัก (Features)

* 🎯 **แถบเครื่องมือลอยอัจฉริยะ (Floating Toolbar)**: เมนูลอยตามเคอร์เซอร์ พร้อมปุ่มคำสั่งด่วนและคีย์ลัด `1`-`9`, `?`, `Esc`
* 📸 **แคปหน้าจอถาม AI (Screen Snipping & Image Ask)**: จับภาพหน้าจอได้ทุกมอนิเตอร์ รองรับ Freeform, ตรวจจับขอบเขตอัจฉริยะ (Smart Detect), และ Auto-Fit
* 📝 **ครอบข้อความถามด่วน (Quick Text Ask)**: คลุมดำข้อความแล้วกดคีย์ลัดเพื่อส่งข้อความพร้อม Prompt เข้า Gemini ทันที
* 🌐 **หน้าต่าง Gemini WebView2 ในตัว**: รันอินเทอร์เฟซ Google Gemini ผ่าน WebView2 เร็ว ปลอดภัย รองรับล็อกอิน Google
* ⚙️ **การปรับแต่งครบครัน**: จัดการ Prompt, สร้างหมวดหมู่คำสั่ง, สลับภาษาไทย/อังกฤษ, ปรับขนาด/ตำแหน่ง Toolbar และตั้งเปิดพร้อม Windows

---

## ⌨️ คีย์ลัดเริ่มต้น (Default Hotkeys)

| คำสั่ง | คีย์ลัด | คำอธิบาย |
| :--- | :--- | :--- |
| **สลับเปิด/ซ่อน Gemini (Boss Key)** | `Alt + F` | เปิดหรือซ่อนหน้าต่างหลัก |
| **แคปหน้าจอถาม AI** | `Alt + Shift + S` | Freeze หน้าจอและเปิดแถบแคปภาพ |
| **คลุมข้อความถามด่วน** | `Ctrl + Caps Lock` | คัดลอกข้อความที่เลือกและเปิด Toolbar |

---

## 📥 ตัวเลือกการดาวน์โหลด (Downloads)

เลือกดาวน์โหลดรูปแบบที่ต้องการได้จาก [Releases](https://github.com/phwyverysad/Gemini-Floating-Toolbar/releases):

1. **⭐ [ไฟล์เดียวจบ] Single-File Portable (`Gemini_Portable.exe`)**: ไฟล์ `.exe` เดียว พกพาไปใช้ได้ทุกเครื่องทันที ไม่ต้องติดตั้ง ไม่ต้องแตก ZIP
2. **🌐 [ตัวติดตั้งออนไลน์] Web Installer (`Gemini_WebSetup.exe`)**: ขนาดเล็กพิเศษ (~2 MB) ติดตั้งลงใน `C:\Program Files\Google Gemini` และสร้างทางลัดหน้าจอ Desktop
3. **💾 [ตัวติดตั้งออฟไลน์เต็ม] Offline Setup (`Gemini_Setup.exe`)**: ติดตั้งลงใน Program Files โดยไม่ต้องใช้อินเทอร์เน็ต
4. **📁 [แบบพกพา ZIP] Portable Archive (`Gemini-Portable.zip`)**: โฟลเดอร์รวมไฟล์รันไทม์ครบชุด

---

## 🛠️ การคอมไพล์จาก Source Code (Build from Source)

### สิ่งที่จำเป็น
* Windows 10/11 (64-bit)
* Visual Studio 2019/2022/2026 (C++ Desktop Development)
* Qt 6.7+ (MSVC 64-bit) พร้อมโมดูล Core, Gui, Qml, Quick, Widgets
* Inno Setup 6 *(สำหรับสร้างตัวติดตั้ง)*

### คำสั่งคอมไพล์และแพ็กเกจ
```cmd
git clone https://github.com/phwyverysad/Gemini-Floating-Toolbar.git
cd Gemini-Floating-Toolbar

# 1. คอมไพล์โปรแกรม
build.bat

# 2. บิลด์แพ็กเกจทุกรูปแบบ (Single-File EXE, Web Installer, Setup)
powershell -ExecutionPolicy Bypass -File package.ps1
```

---

## 📄 สัญญาอนุญาต (License)

โปรเจกต์นี้เผยแพร่ภายใต้สัญญาอนุญาต [MIT License](LICENSE) - Copyright (c) 2026 phwyverysad
