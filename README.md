<div align="center">

# Gemini Floating Toolbar

**โปรแกรมผู้ช่วย Google Gemini บน Windows พร้อมแถบเมนูลอย แคปหน้าจอถาม AI และคีย์ลัดถามด่วน**

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)](https://github.com/phwyverysad/Gemini-Floating-Toolbar)
[![Language](https://img.shields.io/badge/Language-C%2B%2B20%20%7C%20Qt6%20%7C%20QML-00599C?style=flat-square&logo=cplusplus&logoColor=white)](https://en.cppreference.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
[![Download](https://img.shields.io/badge/Download-Latest%20Release-brightgreen?style=flat-square)](https://github.com/phwyverysad/Gemini-Floating-Toolbar/releases)
[![GitHub Stars](https://img.shields.io/github/stars/phwyverysad/Gemini-Floating-Toolbar?style=flat-square&color=gold)](https://github.com/phwyverysad/Gemini-Floating-Toolbar/stargazers)
[![GitHub Issues](https://img.shields.io/github/issues/phwyverysad/Gemini-Floating-Toolbar?style=flat-square&color=orange)](https://github.com/phwyverysad/Gemini-Floating-Toolbar/issues)

[ภาพรวม](#ภาพรวม) | [ฟีเจอร์หลัก](#ฟีเจอร์หลัก) | [การใช้งาน](#การใช้งาน) | [การคอมไพล์จาก Source Code](#การคอมไพล์จาก-source-code) | [ความปลอดภัยและประสิทธิภาพ](#ความปลอดภัยและประสิทธิภาพ) | [สัญญาอนุญาต](#สัญญาอนุญาต)

</div>

---

## ภาพรวม

**Gemini Floating Toolbar** คือแอปพลิเคชัน Desktop Assistant สำหรับระบบปฏิบัติการ Windows พัฒนาด้วยภาษา **C++20, Qt6 (QML)** และ **Microsoft Edge WebView2** ออกแบบมาเพื่อให้ผู้ใช้สามารถเรียกใช้งานและโต้ตอบกับ **Google Gemini AI** ได้อย่างสะดวกรวดเร็วจากทุกหน้าต่างโปรแกรม ผ่านแถบเครื่องมือลอยอัจฉริยะ (Floating Toolbar), การแคปหน้าจอถาม AI (Screen Snipping & Image Query), และคีย์ลัดครอบข้อความถามด่วน (Quick Text Ask)

---

## ฟีเจอร์หลัก

### การทำงานร่วมกับ AI แบบไร้รอยต่อ
* **แถบเมนูลอยอัจฉริยะ (Floating Toolbar)**: แถบเครื่องมือลอยที่แสดงขึ้นตามตำแหน่งเมาส์ พร้อมปุ่มคำสั่งด่วน (เช่น แปลภาษา, สรุปเนื้อหา, อธิบายโค้ด, แก้สมการ)
* **แคปหน้าจอถาม AI (Screen Snipping & Image Query)**: คีย์ลัดเลือกพื้นที่บนหน้าจอเพื่อจับภาพและส่งไปยัง Gemini พร้อม Prompt ที่เลือกได้ทันที
* **ครอบข้อความถามด่วน (Quick Text Ask)**: คลุมดำข้อความในโปรแกรมใดๆ แล้วกดคีย์ลัดเพื่อส่งข้อความเข้า Gemini ได้โดยตรง
* **หน้าต่าง Gemini WebView2 ในตัว**: รันอินเทอร์เฟซ Google Gemini ผ่าน Microsoft Edge WebView2 ที่เร็วและปลอดภัย รองรับการเปิด/ปิดด้วยคีย์ลัดหรือไอคอนถาดระบบ

### การปรับแต่งและการตั้งค่า (Customization & Settings)
* **จัดการ Prompt และหมวดหมู่**: เพิ่ม แก้ไข หรือจัดหมวดหมู่ Prompt คำสั่งสำหรับทั้งรูปภาพและข้อความได้อย่างอิสระ
* **ปรับแต่งแถบ Toolbar**: ปรับขนาด ตำแหน่งการแสดงผล (รอบเคอร์เซอร์/ขอบจอ) และความสูงของ Toolbar
* **รองรับ 2 ภาษา**: สลับภาษาการแสดงผลระหว่าง ภาษาไทย และ ภาษาอังกฤษ
* **เปิดพร้อมระบบปฏิบัติการ**: ตั้งค่าเปิดทำงานอัตโนมัติเมื่อเริ่มต้น Windows (Start with Windows)

---

## การใช้งาน

1. เปิดใช้งานโปรแกรม `Gemini.exe` (โปรแกรมจะทำงานเบื้องหลังบน System Tray)
2. **แคปหน้าจอถาม AI**: กดคีย์ลัดสำหรับจับภาพหน้าจอ แล้วเลือก Prompt บนแถบลอย
3. **ครอบข้อความถามด่วน**: คลุมดำข้อความที่ต้องการแล้วกดคีย์ลัดถามด่วน
4. **เปิด/ปิดหน้าต่าง Gemini**: คลิกซ้ายที่ไอคอนบน System Tray หรือกดคีย์ลัดหลัก
5. **ตั้งค่าโปรแกรม**: คลิกขวาที่ไอคอนบน System Tray เพื่อเปิดหน้าต่าง Settings, สลับภาษา หรือจัดการคำสั่ง Prompt

---

## การคอมไพล์จาก Source Code

### สิ่งที่จำเป็นต้องมี
* ระบบปฏิบัติการ Windows 10 หรือ Windows 11 (64-bit)
* **Microsoft Visual Studio 2019 / 2022 / 2026** (พร้อม C++ Desktop Development)
* **Qt 6.7+** (MSVC 64-bit) พร้อมโมดูล `Core, Gui, Qml, Quick, Widgets`
* **Inno Setup 6** *(ทางเลือก สำหรับสร้างไฟล์ติดตั้ง `Gemini_Setup.exe`)*

### ขั้นตอนการคอมไพล์

1. โคลนคลังข้อมูล (Repository)
   ```cmd
   git clone https://github.com/phwyverysad/Gemini-Floating-Toolbar.git
   cd Gemini-Floating-Toolbar
   ```

2. รันสคริปต์คอมไพล์อัตโนมัติผ่าน `build.bat`
   ```cmd
   build.bat
   ```
   *สคริปต์จะทำการเรียก `qmake`, คอมไพล์ C++ และ QML ด้วย `nmake`, ดีพลอย Qt runtime ด้วย `windeployqt`, และสร้างตัวติดตั้ง Inno Setup ให้โดยอัตโนมัติ*

---

## ความปลอดภัยและประสิทธิภาพ

* **Native & Responsive**: พัฒนาด้วย C++20 และ Qt Quick (QML) ทำให้ UI ลื่นไหล ตอบสนองไว และกินทรัพยากรเครื่องน้อย
* **Secure Web Runtime**: ใช้อินสแตนซ์ WebView2 ที่ปลอดภัยและรองรับการล็อกอินบัญชี Google ได้ตามปกติ

---

## สัญญาอนุญาต

โปรเจกต์นี้เผยแพร่ภายใต้สัญญาอนุญาต MIT License

```
MIT License - Copyright (c) 2026 phwyverysad
```
