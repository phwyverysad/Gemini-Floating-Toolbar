#include "OcrEngine.h"

#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QDebug>
#include <QTemporaryFile>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

#pragma comment(lib, "windowsapp.lib")

using namespace winrt;
using namespace Windows::Foundation;
using namespace Windows::Graphics::Imaging;
using namespace Windows::Media::Ocr;
using namespace Windows::Storage::Streams;

TextScanner& TextScanner::instance() {
    static TextScanner s_instance;
    return s_instance;
}

TextScanner::TextScanner() {
    try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
        m_winMediaOcrAvailable = winrt::Windows::Media::Ocr::OcrEngine::IsLanguageSupported(
            winrt::Windows::Globalization::Language(L"en-US")
        ) || (winrt::Windows::Media::Ocr::OcrEngine::AvailableRecognizerLanguages().Size() > 0);
    } catch (...) {
        m_winMediaOcrAvailable = false;
    }
}

bool TextScanner::isAvailable() const {
    return m_winMediaOcrAvailable || !findTesseractPath().isEmpty();
}

QStringList TextScanner::getAvailableLanguages() const {
    QStringList list;
    try {
        auto langs = winrt::Windows::Media::Ocr::OcrEngine::AvailableRecognizerLanguages();
        for (uint32_t i = 0; i < langs.Size(); ++i) {
            list << QString::fromStdWString(std::wstring(langs.GetAt(i).LanguageTag()));
        }
    } catch (...) {}
    return list;
}

QString TextScanner::findTesseractPath() const {
    // 1. App local Tesseract-OCR folder
    QString appDir = QCoreApplication::applicationDirPath();
    QString p1 = appDir + "/Tesseract-OCR/tesseract.exe";
    if (QFile::exists(p1)) return p1;

    // 2. Project or common relative paths
    QString p2 = "C:/Users/woran/Documents/antigravity/valiant-rutherford/Tesseract-OCR/tesseract.exe";
    if (QFile::exists(p2)) return p2;

    // 3. Program Files
    QString p3 = "C:/Program Files/Tesseract-OCR/tesseract.exe";
    if (QFile::exists(p3)) return p3;

    // 4. PATH lookup
    QString p4 = QStandardPaths::findExecutable("tesseract");
    if (!p4.isEmpty()) return p4;

    return QString();
}

QString TextScanner::recognizeWithWindowsMediaOcr(const QImage& image, const QString& lang) {
    if (image.isNull() || image.width() < 2 || image.height() < 2) return QString();

    try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
    } catch (...) {}

    try {
        QByteArray pngBytes;
        QBuffer buffer(&pngBytes);
        buffer.open(QIODevice::WriteOnly);
        image.save(&buffer, "PNG");

        if (pngBytes.isEmpty()) return QString();

        InMemoryRandomAccessStream stream;
        DataWriter writer(stream);
        writer.WriteBytes(winrt::array_view<const uint8_t>(
            reinterpret_cast<const uint8_t*>(pngBytes.constData()),
            static_cast<uint32_t>(pngBytes.size())
        ));
        writer.StoreAsync().get();
        writer.FlushAsync().get();
        stream.Seek(0);

        BitmapDecoder decoder = BitmapDecoder::CreateAsync(stream).get();
        SoftwareBitmap softwareBitmap = decoder.GetSoftwareBitmapAsync().get();

        winrt::Windows::Media::Ocr::OcrEngine engine = nullptr;

        if (lang != "auto" && !lang.isEmpty()) {
            try {
                winrt::Windows::Globalization::Language targetLang(lang.toStdWString());
                if (winrt::Windows::Media::Ocr::OcrEngine::IsLanguageSupported(targetLang)) {
                    engine = winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromLanguage(targetLang);
                }
            } catch (...) {}
        }

        if (!engine) {
            engine = winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromUserProfileLanguages();
        }

        if (!engine) {
            auto availableLangs = winrt::Windows::Media::Ocr::OcrEngine::AvailableRecognizerLanguages();
            if (availableLangs.Size() > 0) {
                engine = winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromLanguage(availableLangs.GetAt(0));
            }
        }

        if (!engine) return QString();

        OcrResult result = engine.RecognizeAsync(softwareBitmap).get();
        std::wstring textW = std::wstring(result.Text());
        return QString::fromStdWString(textW).trimmed();
    } catch (const winrt::hresult_error& ex) {
        qWarning() << "[OCR] Windows Media OCR failed:" << QString::fromStdWString(std::wstring(ex.message()));
        return QString();
    } catch (const std::exception& ex) {
        qWarning() << "[OCR] Exception:" << ex.what();
        return QString();
    } catch (...) {
        qWarning() << "[OCR] Unknown exception in Windows Media OCR";
        return QString();
    }
}

QString TextScanner::recognizeWithTesseract(const QImage& image, const QString& lang) {
    QString tessPath = findTesseractPath();
    if (tessPath.isEmpty()) return QString();

    QTemporaryFile tempFile(QDir::tempPath() + "/gemini_ocr_XXXXXX.png");
    if (!tempFile.open()) return QString();
    QString tempImgPath = tempFile.fileName();
    tempFile.close();

    image.save(tempImgPath, "PNG");

    QString tessdataDir = QFileInfo(tessPath).absolutePath() + "/tessdata";
    QStringList args;
    args << tempImgPath << "stdout";
    if (QDir(tessdataDir).exists()) {
        args << "--tessdata-dir" << tessdataDir;
    }
    QString tessLang = (lang == "auto" || lang.isEmpty()) ? "tha+eng" : lang;
    args << "-l" << tessLang << "--psm" << "6";

    QProcess proc;
    proc.start(tessPath, args);
    if (!proc.waitForFinished(10000)) {
        proc.kill();
        QFile::remove(tempImgPath);
        return QString();
    }

    QByteArray out = proc.readAllStandardOutput();
    QFile::remove(tempImgPath);
    return QString::fromUtf8(out).trimmed();
}

QString TextScanner::recognizeImage(const QImage& image, const QString& preferredLang) {
    if (image.isNull()) return QString();

    // 1. Primary: Windows Media OCR (Fast native engine)
    QString result = recognizeWithWindowsMediaOcr(image, preferredLang);
    if (!result.isEmpty()) {
        return result;
    }

    // 2. Fallback: Tesseract OCR
    result = recognizeWithTesseract(image, preferredLang);
    return result;
}

